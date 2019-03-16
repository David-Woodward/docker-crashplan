#!/bin/bash

_chkCfgLink() {
    default_cfg=${DEFAULTSDIR}/$(basename ${1})
    dest_cfg_dir=$(dirname ${1})

    if [ -f ${default_cfg} ]; then
        [ -f ${1} ] || ([ -f ${default_cfg} ] && mkdir -p ${dest_cfg_dir} && cp -rp ${default_cfg} ${dest_cfg_dir})
        [ -f ${2} ] && rm -rf ${2}
    else
        [ -d ${1} ] || ([ -d ${default_cfg} ] && mkdir -p ${dest_cfg_dir} && cp -rp ${default_cfg} ${dest_cfg_dir})
        [ -d ${1} ] || mkdir -p ${1}
        [ -d ${2} ] && rm -rf ${2}
    fi
    [ -L ${2} ] || ln -s ${1} ${2}
}

# Update the timezone
[[ -n "${TZ}" ]] && echo "${TZ}" > /etc/timezone

SOURCEDIR=/usr/local/crashplan
DEFAULTSDIR=/defaults

# Initialise the /config directory mounted by the host if needed
_chkCfgLink /config/conf ${SOURCEDIR}/conf
_chkCfgLink /config/log ${SOURCEDIR}/log
_chkCfgLink /config/cache ${SOURCEDIR}/cache
_chkCfgLink /config/repository/metadata ${SOURCEDIR}/metadata
_chkCfgLink /config/manifest ${SOURCEDIR}/manifest
_chkCfgLink /config/var /var/lib/crashplan
_chkCfgLink /config/bin/run.conf ${SOURCEDIR}/bin/run.conf

# Generate machine id to avoid re-login.
[ ! -f /config/machine-id ] && cat /proc/sys/kernel/random/uuid | tr -d '-' > /config/machine-id
[ -f /etc/machine-id ] && rm -f /etc/machine-id
[ ! -L /etc/machine-id ] && ln -sf /config/machine-id /etc/machine-id

# Default values :(
[ -z ${PUBLIC_IP} ] && export PUBLIC_IP=0.0.0.0
[ -z ${PUBLIC_PORT} ] && export PUBLIC_PORT=4244

# For some reason CrashPlan listens to the port above the one listed in the config
CFG_SVC_PORT=$(expr ${PUBLIC_PORT} - 1)
CFG_LOC_PORT=$(expr ${CFG_SVC_PORT} - 1)

# Update configuration files
for cfg in "${SOURCEDIR}/conf/my.service.xml" "${SOURCEDIR}/conf/default.service.xml";
do
    if [[ -f "${cfg}" ]]; then
        # Change the public ip/port dynamicaly and
        # force to use the cache in /var/crashplan/cache (see https://goo.gl/LZ8eRY)
        echo "Configuring CrashPlan to listen on public interface ${PUBLIC_IP}:${PUBLIC_PORT}"

        grep '<location>' "${cfg}" || sed -i -r -e "s@(<config[^>]*>)@\1<location>${PUBLIC_IP}:${CFG_LOC_PORT}</location>@" "${cfg}"

        sed -i -r \
            -e "s/<servicePort>[^<]+/<servicePort>${CFG_SVC_PORT}/g" \
            -e "s/<location>[^<]+/<location>${PUBLIC_IP}:${CFG_LOC_PORT}/g" \
            -e "s@<cachePath>[^<]+@<cachePath>/config/cache@g" \
            -e "s@<manifestPath>[^<]+@<manifestPath>/config/manifest@g" \
            "${cfg}"
    fi
done

# Block upgrades if configured

if [ "${BLOCK_UPGRADES}" == "1" ]; then
    [ -d "${SOURCEDIR}/upgrade" ] && mv -f "${SOURCEDIR}/upgrade" "${DEFAULTSDIR}" && touch "${SOURCEDIR}/upgrade" && chmod 400 "${SOURCEDIR}/upgrade"
else
    [ -f "${SOURCEDIR}/upgrade" ] && rm -f "${SOURCEDIR}/upgrade" && [ -d "${DEFAULTSDIR}/upgrade" ] && mv "${DEFAULTSDIR}/upgrade" "${SOURCEDIR}"
fi

sync

exec $@
