#!/bin/bash

setupPortProxies() {
    for addr in ${1}
    do
        if [ "${addr}" != '127.0.0.1' ] && [ "${addr}" != '::1' ]; then
            echo "Creating a port proxy between ${addr}:${PUBLIC_PORT} and 127.0.0.1:${PUBLIC_PORT} ..."
            if [ -z "${addr##*:*}" ]; then
                socat TCP6-LISTEN:${PUBLIC_PORT},fork,bind=${addr} TCP:127.0.0.1:${PUBLIC_PORT} &
            else
                socat TCP4-LISTEN:${PUBLIC_PORT},fork,bind=${addr} TCP:127.0.0.1:${PUBLIC_PORT} &
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

cfg=/usr/local/crashplan/conf/my.service.xml

[ -f "${cfg}" ] || cfg=/usr/local/crashplan/conf/default.service.xml

svc_port="$(sed -rn 's/.*<servicePort>([0-9]+)<\/servicePort>.*/\1/p' ${cfg})"
ui_port="$(expr ${svc_port} + 1)"

[ -z ${PUBLIC_PORT} ] && export PUBLIC_PORT=${ui_port}

while ! nc -z localhost ${PUBLIC_PORT} && ! nc -z localhost ${svc_port} && ! nc -z localhost ${ui_port}; do
    sleep 0.5
done

cp_version="$(sed -rn 's/.*started,\s+version\s+([^,]+),.*/\1/p' /usr/local/crashplan/log/history.log.0  | tail -1)"

echo "${cp_version}" > /config/cp_version

# Redirect PUBLIC_PORT traffic to 127.0.0.1:4244 for CrashPlan 6 headless operation
# Docker env PUBLIC_IP can be used to limit the listening addresses

nc -z 127.0.0.1 ${svc_port} && actual_port=${svc_port}
nc -z 127.0.0.1 ${ui_port} && actual_port=${ui_port}
nc -z 127.0.0.1 ${PUBLIC_PORT} && actual_port=${PUBLIC_PORT}

echo "CrashPlan service version ${cp_version} has completed initialization and is listening on 127.0.0.1:${actual_port}."

if [ -z ${PUBLIC_IP} ] || [ "${PUBLIC_IP}" == "0.0.0.0" ] || [ "${PUBLIC_IP}" == "127.0.0.1" ]; then
    setupPortProxies "$(ifconfig | sed -rn 's/.*inet\s+addr:\s*(\S+).*/\1/p')"
else
    setupPortProxies "${PUBLIC_IP}"
    [ -z ${primary_ip} ] && setupPortProxies "$(ifconfig | sed -rn 's/.*inet\s+addr:\s*(\S+).*/\1/p')"
fi

# Update .ui_info to allow the user to simply copy the file in some scenarios
[ -f /config/var/.ui_info ] || sleep 5
if [ -f /config/var/.ui_info ]; then
    echo "Updating .ui_info with ${PUBLIC_IP} ..."
    sed -i -r -e "s/([0-9]+,[^,]+,)[0-9\.]+(,.*)/\1${PUBLIC_IP}\2/" /config/var/.ui_info
fi

# Run this process again if the service is restarted
inotifyd '/headless_init.sh' /usr/local/crashplan/CrashPlanEngine.pid:x &
