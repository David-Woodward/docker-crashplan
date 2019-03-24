#!/bin/bash

_chkCfgLink() {
    default_cfg=${DEFAULTS}/$(basename ${1})
    dest_cfg_dir=$(dirname ${1})

    if [ -f ${default_cfg} ]; then
        [ -f ${1} ] || ([ -f ${default_cfg} ] && mkdir -p ${dest_cfg_dir} && cp -rp ${default_cfg} ${dest_cfg_dir})
        [ -f ${2} ] && rm -rf ${2}
    else
        [ -d ${1} ] || ([ -d ${default_cfg} ] && mkdir -p ${dest_cfg_dir} && cp -rp ${default_cfg} ${dest_cfg_dir})
        [ -d ${1} ] || mkdir -p ${1}
        [ -d ${2} ] && rm -rf ${2}
    fi
    [ -d "$(dirname ${2})" ] || mkdir -p "$(dirname ${2})"
    [ -L ${2} ] || ln -s ${1} ${2}
}

# Update the timezone
[[ -n "${TZ}" ]] && echo "${TZ}" > /etc/timezone

CRASHPLAN_PATH=/usr/local/crashplan
DEFAULTS=/defaults
LEGACY_VOL=/var/crashplan
VOL=/config
CP_RESOURCES=${VOL}

# Initialize the volume mounted by the host if needed
if [ -d ${LEGACY_VOL} ]; then
    echo "A legacy/JrCs volume has been detected.  It is recommended that you re-create the"
    echo "container with a clean \"${VOL}\" volume mounted instead.  The legacy"
    echo "volume will continue to work in its current state, but it may not be supported in"
    echo "future releases.  Additionally, in contrast to the legacy volume, the new"
    echo "\"${VOL}\" volume has a structure more consistent/compatible with the"
    echo "jlesage/crashplan-pro docker image allowing easy transition from this image to"
    echo "that image if future CrashPlan releases have breaking changes that prevent the"
    echo "headless functionality in this image from working."

    VOL=${LEGACY_VOL}
    CP_RESOURCES="${LEGACY_VOL}/app"

    # Old JrCs image didn't use machine-id?
    [ -L /etc/machine-id ] || rm -f /etc/machine-id
    [ -f ${VOL}/machine-id ] || touch ${VOL}/machine-id

    _chkCfgLink ${CP_RESOURCES}/metadata ${CRASHPLAN_PATH}/metadata
    _chkCfgLink ${VOL}/id /var/lib/crashplan
else
    _chkCfgLink ${CP_RESOURCES}/repository/metadata ${CRASHPLAN_PATH}/metadata
    _chkCfgLink ${VOL}/var /var/lib/crashplan
fi

_chkCfgLink ${VOL}/conf ${CRASHPLAN_PATH}/conf
_chkCfgLink ${CP_RESOURCES}/log ${CRASHPLAN_PATH}/log
_chkCfgLink ${CP_RESOURCES}/cache ${CRASHPLAN_PATH}/cache
_chkCfgLink ${CP_RESOURCES}/manifest ${CRASHPLAN_PATH}/manifest
_chkCfgLink ${CP_RESOURCES}/bin/run.conf ${CRASHPLAN_PATH}/bin/run.conf

# Generate machine-id to avoid re-login.
[ -f ${VOL}/machine-id ] || cat /proc/sys/kernel/random/uuid | tr -d '-' > ${VOL}/machine-id
[ -f /etc/machine-id ] && rm -f /etc/machine-id
[ -L /etc/machine-id ] || ln -sf ${VOL}/machine-id /etc/machine-id

# Default values :(
[ -z ${PUBLIC_PORT} ] && export PUBLIC_PORT=4244

# For some reason CrashPlan listens to the port above the one listed in the config
CFG_SVC_PORT=$(expr ${PUBLIC_PORT} - 1)
CFG_LOC_PORT=$(expr ${CFG_SVC_PORT} - 1)

# Update configuration files
for cfg in "${CRASHPLAN_PATH}/conf/my.service.xml" "${CRASHPLAN_PATH}/conf/default.service.xml";
do
    if [[ -f "${cfg}" ]]; then
        # Change the listening ports as needed and
        # Force CrashPlan to store cache/manifest in the mounted volume
        # (manifest was formerly used for the incoming backups feature which CP has discontinued)
        grep -q '<location>' "${cfg}" || sed -i -r -e "s|(<config[^>]*>)|\1<location>0.0.0.0:${CFG_LOC_PORT}</location>|" "${cfg}"
        grep -q '<serviceUIConfig>' "${cfg}" || sed -i -r -e "s|(<config[^>]*>)|\1<serviceUIConfig><servicePort>${CFG_SVC_PORT}</servicePort></serviceUIConfig>|" "${cfg}"

        sed -i -r \
            -e "s|<servicePort>[^<]+|<servicePort>${CFG_SVC_PORT}|g" \
            -e "s|<location>[^<]+|<location>0.0.0.0:${CFG_LOC_PORT}|g" \
            -e "s|<cachePath>[^<]+|<cachePath>${CP_RESOURCES}/cache|g" \
            -e "s|<manifestPath>[^<]+|<manifestPath>${CP_RESOURCES}/manifest|g" \
            "${cfg}"
    fi
done

# Block upgrades if configured
if [ "${BLOCK_UPGRADES}" == "1" ]; then
    [ -d "${CRASHPLAN_PATH}/upgrade" ] && mv -f "${CRASHPLAN_PATH}/upgrade" "${DEFAULTS}"
    [ -d "${CRASHPLAN_PATH}/upgrade" ] && rm -rf "${CRASHPLAN_PATH}/upgrade"
    [ ! -d "${CRASHPLAN_PATH}/upgrade" ] && touch "${CRASHPLAN_PATH}/upgrade" && chmod 400 "${CRASHPLAN_PATH}/upgrade"
else
    [ -f "${CRASHPLAN_PATH}/upgrade" ] && rm -f "${CRASHPLAN_PATH}/upgrade" && [ -d "${DEFAULTS}/upgrade" ] && mv "${DEFAULTS}/upgrade" "${CRASHPLAN_PATH}"
fi

sync

exec $@
