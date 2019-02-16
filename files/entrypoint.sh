#!/bin/bash

_link() {
  if [[ -L ${2} && $(readlink ${2}) == ${1} ]]; then
    return 0
  fi
  if [[ ! -e ${1} ]]; then
    if [[ -d ${2} ]]; then
      mkdir -p "${1}"
      pushd ${2} &>/dev/null
      find . -type f -exec cp --parents '{}' "${1}/" \;
      popd &>/dev/null
    elif [[ -f ${2} ]]; then
      if [[ ! -d $(dirname ${1}) ]]; then
        mkdir -p $(dirname ${1})
      fi
      cp -f "${2}" "${1}"
    else
      mkdir -p "${1}"
    fi
  fi
  if [[ -d ${2} ]]; then
    rm -rf "${2}"
  elif [[ -f ${2} || -L ${2} ]]; then
    rm -f "${2}"
  fi
  if [[ ! -d $(dirname ${2}) ]]; then
    mkdir -p $(dirname ${2})
  fi
  ln -sf ${1} ${2}
}

# Update the timezone
[[ -n "$TZ" ]] && echo "$TZ" > /etc/timezone

MOUNTDIR=/var/crashplan
SOURCEDIR=/usr/local/crashplan
TARGETDIR=${MOUNTDIR}/app

if [[ ! -d ${MOUNTDIR}/app ]]; then
    # Migrate the application
    rsync -a --ignore-existing ${MOUNTDIR}/ /tmp/app/
    rm -rf ${MOUNTDIR}/*
    mv /tmp/app ${TARGETDIR}
    rm -f ${TARGETDIR}/install.vars # Will be recreate
fi

[[ -d ${TARGETDIR}/id && ! -d ${MOUNTDIR}/id ]] && mv ${TARGETDIR}/id ${MOUNTDIR}/id

# Populate the TARGETDIR
rsync -a --ignore-existing ${SOURCEDIR}/ ${TARGETDIR}/

# Update install paths
sed -i -r "s@${SOURCEDIR}@${TARGETDIR}@g" \
    /etc/init.d/crashplan \
    ${TARGETDIR}/install.vars

# move binaries, jre, libraries and lang files out of container so crashplan can be upgrade automaticaly
_link ${TARGETDIR}/bin  ${SOURCEDIR}/bin
_link ${TARGETDIR}/jre  ${SOURCEDIR}/jre
_link ${TARGETDIR}/lib  ${SOURCEDIR}/lib
_link ${TARGETDIR}/lang ${SOURCEDIR}/lang

# move identity out of container, this prevent having to adopt account every time you rebuild the Docker
_link ${MOUNTDIR}/id /var/lib/crashplan

# move cache directory out of container, this prevents re-synchronization every time you rebuild the Docker
_link ${TARGETDIR}/cache ${SOURCEDIR}/cache

# move log directory out of container
_link ${TARGETDIR}/log ${SOURCEDIR}/log

# move conf directory out of container
_link ${TARGETDIR}/conf ${SOURCEDIR}/conf
if [[ ! -d ${MOUNTDIR}/conf ]]; then
    mv ${TARGETDIR}/conf ${MOUNTDIR}/conf
else
  rm -rf ${TARGETDIR}/conf
fi
ln -sf ../conf ${TARGETDIR}/conf

# Default values :(
[ -z ${PUBLIC_IP} ] && export PUBLIC_IP=0.0.0.0
[ -z ${PUBLIC_PORT} ] && export PUBLIC_PORT=4244

# For some reason CrashPlan listens to the port above the one listed in the config
CFG_SVC_PORT=$(expr $PUBLIC_PORT - 1)
CFG_LOC_PORT=$(expr $CFG_SVC_PORT - 1)

# Update configuration files
for cfg in "${TARGETDIR}/conf/my.service.xml" "${TARGETDIR}/conf/default.service.xml";
do
  if [[ -f "$cfg" ]]; then
      # Change the public ip/port dynamicaly and
      # force to use the cache in /var/crashplan/cache (see https://goo.gl/LZ8eRY)
      echo "Configuring CrashPlan to listen on public interface $PUBLIC_IP:$PUBLIC_PORT"

      grep '<location>' "$cfg" || sed -i -r -e "s@(<config[^>]*>)@\1<location>$PUBLIC_IP:$CFG_LOC_PORT</location>@" "$cfg"

      sed -i -r \
          -e "s/<servicePort>[^<]+/<servicePort>$CFG_SVC_PORT/g" \
          -e "s/<location>[^<]+/<location>$PUBLIC_IP:$CFG_LOC_PORT/g" \
          -e "s@<cachePath>[^<]+@<cachePath>${TARGETDIR}/cache@g" \
          "$cfg"
  fi
done

# Create some links (not needed by crashplan)
[[ ! -L ${MOUNTDIR}/log ]]  && ln -sf $(basename $TARGETDIR)/log  ${MOUNTDIR}/log

sync

exec $@
