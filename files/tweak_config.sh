#!/bin/sh

if [ ! -f /tmp/tweak_config.tmp ] && [ -f "${CRASHPLAN_PATH}/conf/my.service.xml" ] && [ -f "${VOL}/my.service.xml.remove" ]; then
    touch /tmp/tweak_config.tmp
    if [ -z "$1" ]; then
        echo 'Removing text from "my.service.xml" as specified in "my.service.xml.remove" ...'
    else
        echo "$1  Removing text from \"my.service.xml\" as specified in \"my.service.xml.remove\" ..."
    fi
    cat "${VOL}/my.service.xml.remove" | while read i;
    do
        if grep -q "${i}" "${CRASHPLAN_PATH}/conf/my.service.xml"; then
            echo "Removing \"${i}\" ..."
            sed -i "/$(echo ${i} | sed 's/\//\\\//g')/d" "${CRASHPLAN_PATH}/conf/my.service.xml"
        fi
    done
    rm -f /tmp/tweak_config.tmp
fi
