#!/bin/sh

set -e

[ -z ${CRASHPLAN_PATH} ] && CRASHPLAN_PATH=/usr/local/crashplan

# Move configuration directories out of the container and capture any defaults created during installation
mkdir -p /defaults

[ -d ${CRASHPLAN_PATH}/conf ] && mv -f ${CRASHPLAN_PATH}/conf /defaults
[ -f ${CRASHPLAN_PATH}/bin/run.conf ] && mv -f ${CRASHPLAN_PATH}/bin/run.conf /defaults
[ -d ${CRASHPLAN_PATH}/cache ] && mv -f ${CRASHPLAN_PATH}/cache /defaults
[ -d ${CRASHPLAN_PATH}/log ] && mv -f ${CRASHPLAN_PATH}/log /defaults
[ -d /var/lib/crashplan ] && mv -f /var/lib/crashplan /defaults/var
[ -d ${CRASHPLAN_PATH}/metadata ] && mv -f ${CRASHPLAN_PATH}/metadata /defaults
[ -d /config/manifest ] && mv -f /config/manifest /defaults
