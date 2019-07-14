#!/bin/bash

# Update the timezone
[ -n "${TZ}" ] && echo "${TZ}" > /etc/timezone

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


# Assign default values to variables
[ -z "${CRASHPLAN_PATH}" ] && export CRASHPLAN_PATH=/usr/local/crashplan
[ -z "${KEEP_APP_RUNNING}" ] && export KEEP_APP_RUNNING=1
[ -z "${STOP_CONTAINER_WITH_APP}" ] && export STOP_CONTAINER_WITH_APP=0
[ -z "${CRASH_RESPONSE_DELAY}" ] && export CRASH_RESPONSE_DELAY=30
[ -z "${USER_ID}" ] && export USER_ID=0
[ -z "${GROUP_ID}" ] && export GROUP_ID=0
[ -z "${BLOCK_UPGRADES}" ] && export BLOCK_UPGRADES=1
[ -z "${CLEAN_UPGRADES}" ] && export CLEAN_UPGRADES=0
[ -z "${LOG_FILES}" ] && export LOG_FILES="$(sed -rn 'N;s|.*<RollingFile\s+name\s*=\s*"HistoryLog"\s*>\s*<filename>.+[}/]+([^/]+)</filename>.*|\1|p;D' "${VOL}/conf/service.log.xml")"
[ -z "${PUBLIC_PORT}" ] && export PUBLIC_PORT=4244

# Generate machine-id to avoid re-login.
[ -f ${VOL}/machine-id ] || cat /proc/sys/kernel/random/uuid | tr -d '-' > ${VOL}/machine-id
[ -f /etc/machine-id ] && rm -f /etc/machine-id
[ -L /etc/machine-id ] || ln -sf ${VOL}/machine-id /etc/machine-id


#
# Setup the CrashPlan user/group with the configured user/group ID (root by default)
#

# Remove the nobody user if CrashPlan will be using it
if [ "${USER_ID}" == "$(grep -E '^nobody:' /etc/passwd | cut -d':' -f3)" ]; then
    sed -i -r -e '/^nobody:/d' /etc/passwd
    sed -i -r -e '/^nobody:/d' /etc/shadow
fi

# Remove any previously created user/groups
sed -i -r -e '/^cpuser:/d' /etc/passwd
sed -i -r -e "s/^([^:]+:[^:]+:[0-9]:.*)(,?cpuser)(,|$)/\1\3/g" -e '/^cpgroup[0-9]+:/d' /etc/group

# Add cpuser
echo "cpuser:x:${USER_ID}:${GROUP_ID}::/config:" >> /etc/passwd

# Add cpuser to any existing groups that match the IDs in GROUP_ID and SUP_GROUP_IDS and create dummy groups for IDs that aren't matched
group_num=0
for gid in $GROUP_ID $(echo ${SUP_GROUP_IDS} | tr ',' ' ')
do
    if grep -q -E "^[^:]+:[^:]+:${gid}:" /etc/group; then
        [ "${GROUP_ID}" != "${gid}" ] && sed -i -r -e "s/^([^:]+:[^:]+:${gid}:.+)$/\1,cpuser/g" -e "s/^([^:]+:[^:]+:${gid}:)$/\1cpuser/g" /etc/group
    elif [ "${GROUP_ID}" == "${gid}" ]; then
        group_num=$(expr ${group_num} + 1)
        echo "cpgroup${group_num}:x:${gid}" >> /etc/group
    else
        group_num=$(expr ${group_num} + 1)
        echo "cpgroup${group_num}:x:${gid}:cpuser" >> /etc/group
    fi
done

exec $@
