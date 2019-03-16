#!/bin/bash

setupPortProxies() {
    for addr in ${1}
    do
        if [ "${addr}" != '127.0.0.1' ] && [ "${addr}" != '::1' ]; then
            echo "Creating a port proxy between ${addr}:${PUBLIC_PORT} and ${ui_port} ..."
            if [ -z "${addr##*:*}" ]; then
                socat TCP6-LISTEN:${PUBLIC_PORT},fork,bind=${addr} TCP:${ui_port} &
            else
                socat TCP4-LISTEN:${PUBLIC_PORT},fork,bind=${addr} TCP:${ui_port} &
            fi
            sleep .5
            kill -0 $! 2>/dev/null && [ -z ${primary_ip} ] && primary_ip=${addr}
        fi
    done
}

# Kill any old socat instances
for socat_pid in $(ps -o pid,cmd -U root | grep -v grep | grep socat | sed -rn 's/\s*([0-9]+).*/\1/p')
do
    kill ${socat_pid};
done

# Wait for CrashPlan to start and capture the version from the log file
echo "Waiting for the CrashPlan service to initialize ..."

# Get the possible ports from the config file, ports being listened to by java, and PUBLIC_PORT
cfg="${CRASHPLAN_PATH}/conf/my.service.xml"

while ui_port="$(netstat -ltnp 2>/dev/null | grep 'java' | head -n 1 | awk '{ print $4 }')" && [ -z ${ui_port} ]; do sleep .5; done
svc_port="$(sed -rn 's/.*<servicePort>([0-9]+)<\/servicePort>.*/\1/p' ${cfg})"
[ -z ${PUBLIC_PORT} ] && export PUBLIC_PORT=${ui_port##*:}

cp_version="$(sed -rn 's/.*started,\s+version\s+([^,]+),.*/\1/p' /usr/local/crashplan/log/history.log.0  | tail -1)"

echo "${cp_version}" > /config/cp_version

# Redirect PUBLIC_PORT traffic to 127.0.0.1:4244 for CrashPlan 6 headless operation
# Docker env PUBLIC_IP can be used to limit the listening addresses

echo "CrashPlan service version ${cp_version} has completed initialization and is listening on ${ui_port}."

if [ -z ${PUBLIC_IP} ] || [ "${PUBLIC_IP}" == "0.0.0.0" ] || [ "${PUBLIC_IP}" == "127.0.0.1" ]; then
    setupPortProxies "$(ifconfig | sed -rn 's/.*inet\s+addr:\s*(\S+).*/\1/p')"
else
    setupPortProxies "${PUBLIC_IP}"
    [ -z ${primary_ip} ] && setupPortProxies "$(ifconfig | sed -rn 's/.*inet\s+addr:\s*(\S+).*/\1/p')"
fi

# Update .ui_info to allow the user to simply copy the file in some scenarios
[ -f /config/var/.ui_info ] || sleep 5
if [ -f /config/var/.ui_info ]; then
    host_ip=${primary_ip}
    [ -z ${PUBLIC_IP} ] || host_ip="$(echo ${PUBLIC_IP} | cut -d' ' -f1)"
    echo "Updating .ui_info to direct clients to ${host_ip}:${PUBLIC_PORT} ..."
    sed -i -r -e "s/[0-9]+,([^,]+,)[0-9\.]+(,.*)/$(expr ${PUBLIC_PORT} - 1),\1${host_ip}\2/" /config/var/.ui_info
fi

# Run this process again if the service is restarted
inotifyd '/headless_init.sh' /usr/local/crashplan/CrashPlanEngine.pid:x &
