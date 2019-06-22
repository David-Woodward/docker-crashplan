#!/bin/sh

set -e

[ -z ${CRASHPLAN_PATH} ] && CRASHPLAN_PATH=/usr/local/crashplan

# Patch CrashPlanEngine (this may no longer be necessary - degraded to a warning for now)
# [ DISABLED AS OF CRASHPLAN SMB 7.0.0 UNTIL NECESSITY CAN BE DETERMINED ]
# cd "${CRASHPLAN_PATH}" && patch -p1 < /app/CrashPlanEngine.patch || echo "WARNING: Unable to patch CrashPlanEngine ($?)"
