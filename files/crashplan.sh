#!/bin/bash

source /app/cleanup.sh

CP_PID_FILE="${CRASHPLAN_PATH}/CrashPlanEngine.pid"

crashplan() {
    /app/run_prep.sh
    su cpuser /etc/init.d/crashplan ${1}
    CP_PID="$(cat "${CP_PID_FILE}")"
}

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

crashplan start

for file in $(echo ${LOG_FILES} | tr ',' ' '); do
    full_path="${CRASHPLAN_PATH}/log/${file}"
    [ ! -f "${full_path}" ] && touch "${full_path}" && chown cpuser:${GROUP_ID} "${full_path}"
    FULLPATH_LOG_FILES="${full_path} ${FULLPATH_LOG_FILES}"
done

tail -n0 -F ${FULLPATH_LOG_FILES} &
tail_pid=$!

/app/headless_init.sh &
headless_pid=$!



if [ "${KEEP_APP_RUNNING}" == "1" ] || [ "${STOP_CONTAINER_WITH_APP}" == "1" ]; then
    # Wait for the CrashPlan service to stop and restart it

    if [ "${KEEP_APP_RUNNING}" == "1" ]; then
        echo "KEEP_APP_RUNNING=1 - monitoring the CrashPlan service (pid ${CP_PID}) with a ${CRASH_RESPONSE_DELAY}+ second delay for user interventon."
    else
        echo "STOP_CONTAINER_WITH_APP=1 - monitoring the CrashPlan service (pid ${CP_PID}) with a ${CRASH_RESPONSE_DELAY}+ second delay for user intervention."
    fi

    while true
    do
        while [ ! -z ${CP_PID} ] && kill -0 ${CP_PID} 2>/dev/null;
        do
            sleep $(expr ${CRASH_RESPONSE_DELAY} '*' 2)
            CP_PID="" && [ -f "${CP_PID_FILE}" ] && CP_PID="$(cat "${CP_PID_FILE}")"
        done

        echo "The CrashPlan service has stopped - waiting ${CRASH_RESPONSE_DELAY} seconds to allow for user intervention, upgrade completion, or self-repair."

        sleep ${CRASH_RESPONSE_DELAY}

        if /etc/init.d/crashplan status | grep -q 'stopped'; then
            CP_PID=""
            if [ -d "${CRASHPLAN_PATH}/upgrade" ] && ls -lad "${CRASHPLAN_PATH}/upgrade/"*/ > /dev/null 2>&1; then
                echo "CrashPlan appears to be upgrading - service monitoring temporarily disabled."
            else
                if [ "${KEEP_APP_RUNNING}" == "1" ]; then
                    echo 'Restarting the CrashPlan service now.'
                    crashplan start
                else
                    echo 'Stopping the Docker container now.'
                    term_handler
                fi
            fi
        fi

        while [ -z ${CP_PID} ] || ! kill -0 ${CP_PID} 2>/dev/null
        do
            sleep .5
            [ -f "${CP_PID_FILE}" ] && CP_PID="$(cat "${CP_PID_FILE}")"
        done
    done
else
    # wait "indefinitely"
    while [[ -e /proc/${tail_pid} ]]; do
        wait ${tail_pid} # Wait for any signals or end of execution of tail
    done
fi

# Stop container properly
term_handler
