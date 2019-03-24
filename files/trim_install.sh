#!/bin/sh

set -e

[ -z ${CRASHPLAN_PATH} ] && CRASHPLAN_PATH=/usr/local/crashplan

rm -rf \
${CRASHPLAN_PATH}/upgrade \
${CRASHPLAN_PATH}/electron \
${CRASHPLAN_PATH}/jre/lib/plugin.jar \
${CRASHPLAN_PATH}/jre/lib/ext/jfxrt.jar \
${CRASHPLAN_PATH}/jre/bin/javaws \
${CRASHPLAN_PATH}/jre/lib/javaws.jar \
${CRASHPLAN_PATH}/jre/lib/desktop \
${CRASHPLAN_PATH}/jre/plugin \
${CRASHPLAN_PATH}/jre/lib/deploy* \
${CRASHPLAN_PATH}/jre/lib/*javafx* \
${CRASHPLAN_PATH}/jre/lib/*jfx* \
${CRASHPLAN_PATH}/jre/lib/amd64/libdecora_sse.so \
${CRASHPLAN_PATH}/jre/lib/amd64/libprism_*.so \
${CRASHPLAN_PATH}/jre/lib/amd64/libfxplugins.so \
${CRASHPLAN_PATH}/jre/lib/amd64/libglass.so \
${CRASHPLAN_PATH}/jre/lib/amd64/libgstreamer-lite.so \
${CRASHPLAN_PATH}/jre/lib/amd64/libjavafx*.so \
${CRASHPLAN_PATH}/jre/lib/amd64/libjfx*.so
