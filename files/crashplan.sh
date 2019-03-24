#!/bin/bash

source /app/cleanup.sh

# SIGTERM-handler
term_handler() {

    # Stop the headless script responsible for monitoring CrashPlan pid changes and socat processes
    # (depending on the implementation, this process may have already exited on its own)
    kill "${headless_pid}" 2>/dev/null

    # Cleanup any dangling processes left from the headless script
    cleanup_procs '(socat|inotify)'

    # Stop crashplan
    /etc/init.d/crashplan stop

    # Check for rogue/zombie processes and kill them
    cleanup_procs

    exit 143; # 128 + 15 -- SIGTERM
}

# Kill logging (tail) and then run standard cleanup proceedures
trap 'kill "${tail_pid}"; term_handler' INT QUIT KILL TERM

/etc/init.d/crashplan start

LOGS_FILES="/usr/local/crashplan/log/service.log.0"
for file in ${LOGS_FILES}; do
    [[ ! -f "${file}" ]] && touch ${file}
done

tail -n0 -F ${LOGS_FILES} &
tail_pid=$!

/app/headless_init.sh &
headless_pid=$!

# wait "indefinitely"
while [[ -e /proc/${tail_pid} ]]; do
    wait ${tail_pid} # Wait for any signals or end of execution of tail
done

# Stop container properly
term_handler
