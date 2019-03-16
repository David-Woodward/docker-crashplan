#!/bin/sh

set -e

CRASHPLAN_URL=$1
SOURCEDIR=/usr/local/crashplan

install_deps='expect'
apk add --update bash openssl findutils coreutils procps libstdc++ rsync $install_deps
apk add cpio --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/community/

mkdir /tmp/crashplan

echo "Downloading CrashPlan for Small Business ..."
wget -O- --progress=bar:force ${CRASHPLAN_URL} \
    | tar -xz --strip-components=1 -C /tmp/crashplan


mkdir -p /usr/share/applications
cd /tmp/crashplan && chmod +x /tmp/installation/crashplan.exp && sync && /tmp/installation/crashplan.exp || exit $?
echo

# Stop CrashPlan if it actually started
/etc/init.d/crashplan stop || true
sleep 2

cd / && rm -rf /tmp/crashplan
rm -rf /usr/share/applications

# Patch CrashPlanEngine
cd "${SOURCEDIR}" && patch -p1 < /tmp/installation/CrashPlanEngine.patch || exit $?

# move configuration directories out of the container and capture any defaults created during installation
mkdir -p /defaults

SOURCEDIR=/usr/local/crashplan

[ -d ${SOURCEDIR}/conf ] && mv -f ${SOURCEDIR}/conf /defaults
[ -f ${SOURCEDIR}/bin/run.conf ] && mv -f ${SOURCEDIR}/bin/run.conf /defaults
[ -d ${SOURCEDIR}/cache ] && mv -f ${SOURCEDIR}/cache /defaults
[ -d ${SOURCEDIR}/log ] && mv -f ${SOURCEDIR}/log /defaults
[ -d /var/lib/crashplan ] && mv -f /var/lib/crashplan /defaults/var
[ -d ${SOURCEDIR}/metadata ] && mv -f ${SOURCEDIR}/metadata /defaults
[ -d /config/manifest ] && mv -f /config/manifest /defaults

# Install launchers
mv /tmp/installation/entrypoint.sh /tmp/installation/crashplan.sh /tmp/installation/headless-init.sh /

# Remove unneccessary package
apk del $install_deps

# Remove unneccessary files and directories
rm -rf ${SOURCEDIR}/*.pid \
   ${SOURCEDIR}/electron \
   ${SOURCEDIR}/jre/lib/plugin.jar \
   ${SOURCEDIR}/jre/lib/ext/jfxrt.jar \
   ${SOURCEDIR}/jre/bin/javaws \
   ${SOURCEDIR}/jre/lib/javaws.jar \
   ${SOURCEDIR}/jre/lib/desktop \
   ${SOURCEDIR}/jre/plugin \
   ${SOURCEDIR}/jre/lib/deploy* \
   ${SOURCEDIR}/jre/lib/*javafx* \
   ${SOURCEDIR}/jre/lib/*jfx* \
   ${SOURCEDIR}/jre/lib/amd64/libdecora_sse.so \
   ${SOURCEDIR}/jre/lib/amd64/libprism_*.so \
   ${SOURCEDIR}/jre/lib/amd64/libfxplugins.so \
   ${SOURCEDIR}/jre/lib/amd64/libglass.so \
   ${SOURCEDIR}/jre/lib/amd64/libgstreamer-lite.so \
   ${SOURCEDIR}/jre/lib/amd64/libjavafx*.so \
   ${SOURCEDIR}/jre/lib/amd64/libjfx*.so \
   /config

rm -rf /boot /home /lost+found /media /mnt /run /srv
rm -rf /var/cache/apk/*
rm -f  /root/.wget-hsts
