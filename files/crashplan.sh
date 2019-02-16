#!/bin/bash

# SIGTERM-handler
term_handler() {

    # Stop crashplan
    /etc/init.d/crashplan stop

    exit 143; # 128 + 15 -- SIGTERM
}

# Kill logging (tail) and port proxy (socat) processes
trap 'kill "$tail_pid"; \
      for headless_pid in $(ps -eo pid,cmd | grep -v grep | grep socat | awk "{print \$1}"); do kill "${headless_pid}"; done; \
      term_handler' INT QUIT KILL TERM

/etc/init.d/crashplan start

LOGS_FILES="/var/crashplan/log/service.log.0"
for file in $LOGS_FILES; do
	[[ ! -f "$file" ]] && touch $file
done

tail -n0 -F $LOGS_FILES &
tail_pid=$!


# Redirect 4244 traffic to localhost for CrashPlan 6 headless operation
# Docker env PUBLIC_IP can be used to limit the listening addresses
[ -z ${PUBLIC_IP} ] || [ "${PUBLIC_IP}" == '0.0.0.0' ] || [ "${PUBLIC_IP}" == '127.0.0.1' ] && PUBLIC_IP=$(ifconfig | sed -rn 's/.*inet\s+addr:\s*(\S+).*/\1/p')

for addr in ${PUBLIC_IP}
do
  if [ "${addr}" != '127.0.0.1' ] && [ "${addr}" != '::1' ]; then
    if [ -z "${addr##*:*}" ]; then
      socat TCP6-LISTEN:${PUBLIC_PORT},fork,bind=${addr} TCP:127.0.0.1:${PUBLIC_PORT} &
    else
      socat TCP4-LISTEN:${PUBLIC_PORT},fork,bind=${addr} TCP:127.0.0.1:${PUBLIC_PORT} &
    fi
  fi
done


# wait "indefinitely"
while [[ -e /proc/$tail_pid ]]; do
    wait $tail_pid # Wait for any signals or end of execution of tail
done

# Stop container properly
term_handler
