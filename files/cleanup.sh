#!/bin/sh

cleanup_procs() {
    ps -eo pid,cmd --noheaders | grep -E "${1}" | grep -v -E '^\s*[0-9]+\s+(grep|ps|.*(/|\s)crashplan\.sh)(\s|$)' | while read -r old_pid old_cmd
    do
        if [ ${old_pid} != 1 ]; then
            echo "Terminating process ${old_pid} - ${old_cmd}"
            kill_counter=8
            if kill ${old_pid}; then
                while [ ${kill_counter} -gt 0 ] && old_s=$(ps -p ${old_pid} -o s --noheaders) && [ ! -z ${old_s} ] && [ "${old_s}" != "Z" ]
                do
                    sleep .5
                    kill_counter=$(expr ${kill_counter} - 1)
                done
                [ ${kill_counter} == 0 ] && echo "Killing process ${old_pid} - ${old_cmd}" && kill -9 ${old_pid}
            fi
        fi
    done
}
