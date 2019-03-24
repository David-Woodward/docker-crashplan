#!/bin/bash

# Update the timezone
[ -n "${TZ}" ] && echo "${TZ}" > /etc/timezone

# Assign default values to variables
[ -z ${CRASHPLAN_PATH} ] && export CRASHPLAN_PATH=/usr/local/crashplan
[ -z ${KEEP_APP_RUNNING} ] && export KEEP_APP_RUNNING=1
[ -z ${STOP_CONTAINER_WITH_APP} ] && export STOP_CONTAINER_WITH_APP=0
[ -z ${CRASH_RESPONSE_DELAY} ] && export CRASH_RESPONSE_DELAY=30
[ -z ${BLOCK_UPGRADES} ] && export BLOCK_UPGRADES=1
[ -z ${CLEAN_UPGRADES} ] && export CLEAN_UPGRADES=0
[ -z ${LOG_FILES} ] && export LOG_FILES='history.log.0'
[ -z ${PUBLIC_PORT} ] && export PUBLIC_PORT=4244

export LEGACY_VOL=/var/crashplan
export NEW_VOL=/config
export VOL=${NEW_VOL}


# Check for the legacy volume
if [ -d ${LEGACY_VOL} ]; then
    export VOL=${LEGACY_VOL}

    echo "A legacy/JrCs volume has been detected.  It is recommended that you re-create the"
    echo "container with a clean \"${NEW_VOL}\" volume mounted instead.  The legacy"
    echo "volume will continue to work in its current state, but it may not be supported in"
    echo "future releases.  Additionally, in contrast to the legacy volume, the new"
    echo "\"${NEW_VOL}\" volume has a structure more consistent/compatible with the"
    echo "jlesage/crashplan-pro docker image allowing easy transition from this image to"
    echo "that image if future CrashPlan releases contain breaking changes that prevent the"
    echo "headless functionality in this image from working."

    # The JrCs image didn't use the machine-id
    [ -f ${VOL}/machine-id ] || touch ${VOL}/machine-id
fi


# Generate machine-id to avoid re-login.
[ -f ${VOL}/machine-id ] || cat /proc/sys/kernel/random/uuid | tr -d '-' > ${VOL}/machine-id
[ -f /etc/machine-id ] && rm -f /etc/machine-id
[ -L /etc/machine-id ] || ln -sf ${VOL}/machine-id /etc/machine-id

exec $@
