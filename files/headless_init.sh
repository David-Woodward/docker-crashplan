#!/bin/bash

source /app/cleanup.sh

setupPortProxies() {
    socat_dest="TCP:${ui_port}"
    [ "${ui_port##*:}" == "${ui_port#*:}" ] || socat_dest="TCP6:[${ui_port%:*}]:${ui_port##*:}"

    for addr in ${1}
    do
        if [ "${addr}" != '127.0.0.1' ] && [ "${addr}" != '::1' ]; then
            echo "Creating a port proxy between ${addr}:${PUBLIC_PORT} and ${ui_port} ..."
            if [ -z "${addr##*:*}" ]; then
                if [ "${addr}" == "${PUBLIC_IP}" ] && ! ifconfig 2>&1 | grep -q "${addr}"; then
                    socat TCP6-LISTEN:${PUBLIC_PORT},fork,bind=[${addr}] ${socat_dest} > /dev/null 2>&1 &
                else
                    socat TCP6-LISTEN:${PUBLIC_PORT},fork,bind=[${addr}] ${socat_dest} &
                fi
            else
                if [ "${addr}" == "${PUBLIC_IP}" ] && ! ifconfig 2>&1 | grep -q "${addr}"; then
                    socat TCP4-LISTEN:${PUBLIC_PORT},fork,bind=${addr} ${socat_dest} > /dev/null 2>&1 &
                else
                    socat TCP4-LISTEN:${PUBLIC_PORT},fork,bind=${addr} ${socat_dest} &
                fi
            fi
            sleep .5
            kill -0 $! 2>/dev/null && ([ -z ${primary_ip} ] || ([ -z ${primary_ip##*:*} ] && [ ! -z ${addr##*:*} ])) && primary_ip=${addr}
        fi
    done
}

getInterfaceIPs() {
    ifconfig | awk '
        /^[a-z]/ {interface = $1}
        match(interface, /^'${1}':?$/, i) && match($0, /^.*\sinet( addr)?(:\s*|\s+)([\.0-9]+)/, a) { print a[3] }
        match(interface, /^'${1}':?$/, i) && match($0, /^.*\sinet6( addr)?:?\s+([\.0-9a-f:]+)/, a) { print a[2] }
        '
}

#SIGTERM-handler
term_handler() {
    cleanup_procs '(socat|inotify)'

    exit 143; # 128 + 15 -- SIGTERM
}


trap 'term_handler' INT QUIT KILL TERM

# Use a while loop for Ubuntu based Docker images
#while true; do

#
# Wait for CrashPlan to start and capture the version from the log file
#
echo "Waiting for the CrashPlan service to initialize ..."

# Kill any old processes still running from the last execution of this script
cleanup_procs '(socat|inotify)'

# If KEEP_APP_RUNNING=1 then the inotify event that spawned this process will likely
# be the most timely/efficient way to restart the service when it stops.
if [ "${KEEP_APP_RUNNING}" == "1" ] && /etc/init.d/crashplan status | grep -q 'stopped' && ( [ ! -d "${CRASHPLAN_PATH}/upgrade" ] || ! ls -lad "${CRASHPLAN_PATH}/upgrade/"*/ > /dev/null 2>&1 ); then
    secs=0
    while [ ${secs} -lt $(expr ${CRASH_RESPONSE_DELAY} '*' 2) ]
    do
        sleep .5
        /etc/init.d/crashplan status | grep -q 'stopped' || break
        [ -d "${CRASHPLAN_PATH}/upgrade" ] && ls -lad "${CRASHPLAN_PATH}/upgrade/"*/ > /dev/null 2>&1 && break
        secs=$(expr ${secs} + 1)
    done
    if /etc/init.d/crashplan status | grep -q 'stopped' && ( [ ! -d "${CRASHPLAN_PATH}/upgrade" ] || ! ls -lad "${CRASHPLAN_PATH}/upgrade/"*/ > /dev/null 2>&1 ); then
        echo 'The CrashPlan service has stopped - restarting it now'
        /app/run_prep.sh
        su cpuser /etc/init.d/crashplan start
    fi
fi

# Get the possible ports from the config file, ports being listened to by java, and PUBLIC_PORT
cfg="${CRASHPLAN_PATH}/conf/my.service.xml"

while ui_port="$(netstat -ltnp 2>/dev/null | grep 'java' | head -n 1 | awk '{ print $4 }')" && [ -z ${ui_port} ]; do sleep .5; done
svc_port="$(sed -rn 's/.*<servicePort>([0-9]+)<\/servicePort>.*/\1/p' ${cfg})"
[ -z ${PUBLIC_PORT} ] && export PUBLIC_PORT=${ui_port##*:}

# Capture the CP version from the log file
cp_version="$(sed -rn 's/.*started,\s+version\s+([^,]+),.*/\1/p' "${CRASHPLAN_PATH}/log/history.log.0" | tail -1)"
echo "${cp_version}" > /config/cp_version


echo "CrashPlan service version ${cp_version} has completed initialization and is listening on ${ui_port}."

# Get default ip address list from eth0
default_interface_ip_list=$( getInterfaceIPs 'eth0' )

# Get the IP addresses specified by the user in PUBLIC_IP and/or PUBLIC_INTERFACE
# (if the user did not specify an IP address or interface, all addresses detected on the system will be used)
if [ "${PUBLIC_INTERFACE,,}" == 'eth0' ]; then
    public_ip_list="${default_interface_ip_list} ${PUBLIC_IP}"
elif [ ! -z ${PUBLIC_INTERFACE} ]; then
    public_ip_list="$( getInterfaceIPs ${PUBLIC_INTERFACE} ) ${PUBLIC_IP}"
elif [ ! -z ${PUBLIC_IP} ]; then
    public_ip_list=${PUBLIC_IP}
else
    # first get ALL ip addresses
    public_ip_list=$(ifconfig | sed -rn 's/.*inet6?( addr)?(:\s*|\s+)([\.0-9a-f:]+).*/\3/p')
	
    # now remove the default ip's from the list and add them back to the beginning for priority
    for def_ip in ${default_interface_ip_list}; do public_ip_list=$(echo ${public_ip_list} | sed "s/\b${def_ip}\b//g"); done
	public_ip_list="${default_interface_ip_list} ${public_ip_list}"
fi

# Redirect PUBLIC_PORT traffic to 127.0.0.1:4244 for CrashPlan 6 headless operation
setupPortProxies "${public_ip_list}"

if [ -z ${primary_ip} ]; then
    echo "Errors were encountered setting up port proxies on all of the configured IP addresses."
    if [ ! -z ${default_interface_ip_list} ] && [ "${public_ip_list}" != "${default_interface_ip_list}" ]; then
        echo "Attempting to setup a port proxy for the default interface IP(s) ..."
        setupPortProxies "${default_interface_ip_list}"
    fi
fi

if [ -z ${primary_ip} ]; then
    echo "Unable to configure port proxies.  Headless operation may not be possible."
else
    # Update .ui_info with our best guess for the host machine's IP address (PUBLIC_IP if specified).
    # This can potentially allow the user to simply copy the .ui_info and service.pem file to their
    # system to achieve headless operation without any modification of the files on their part.
    [ -f /config/var/.ui_info ] || sleep 5
    if [ -f /config/var/.ui_info ]; then
        host_ip=${primary_ip}
        [ -z ${PUBLIC_IP} ] || host_ip="$(echo ${PUBLIC_IP} | cut -d' ' -f1)"
        echo "Updating .ui_info to direct clients to ${host_ip}:${PUBLIC_PORT} ..."
        sed -i -r -e "s/[0-9]+,([^,]+,)[0-9\.]+(,.*)/$(expr ${PUBLIC_PORT} - 1),\1${host_ip}\2/" /config/var/.ui_info
    fi
fi

# Run this process again if the service is restarted
inotifyd '/app/headless_init.sh' "${CRASHPLAN_PATH}/CrashPlanEngine.pid":x &

# Use a while loop for Ubuntu based Docker images
#inotifywait -e delete_self "${CRASHPLAN_PATH}/CrashPlanEngine.pid" || break
#done
#term_handler
