#!/bin/sh

set -e

[ -z ${CRASHPLAN_PATH} ] && CRASHPLAN_PATH=/usr/local/crashplan

# Patch CrashPlanEngine (this may no longer be necessary - degraded to a warning for now)
cd "${CRASHPLAN_PATH}" && patch -p1 < /app/CrashPlanEngine.patch || echo "WARNING: Unable to patch CrashPlanEngine ($?)"
