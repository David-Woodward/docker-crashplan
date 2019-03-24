##### Ubuntu equivalent of Apline specific lines below
# FROM ubuntu:latest
# RUN apt-get update && \
#     apt-get install -y wget ca-certificates socat gawk openssl cpio net-tools netcat inotify-tools patch && \
#     apt-get install -y ${CRASHPLAN_INSTALLER_DEPENCIES} && \
#     apt-get purge ${CRASHPLAN_INSTALLER_DEPENCIES} && apt-get clean && rm -rf /var/lib/apt/lists/* &&\
#     rm -rf /var/lib/apt/lists/*

FROM alpine:3.9

#########################################
##        ENVIRONMENTAL CONFIG         ##
#########################################
# Set correct environment variables
ENV LC_ALL=en_US.UTF-8      \
    LANG=en_US.UTF-8        \
    LANGUAGE=en_US.UTF-8

#########################################
##   BASE IMAGE SETUP AND CP INSTALL   ##
#########################################
ADD /files/crashplan.exp /files/trim_install.sh /files/move_config.sh /tmp/installation/

# Here we install GNU libc (aka glibc) and set en_US.UTF-8 locale as default.
RUN CRASHPLAN_VERSION=6.9.2 && \
    CRASHPLAN_TIMESTAMP=1525200006692 && \
    CRASHPLAN_BUILD=759 && \
    CRASHPLAN_URL=https://web-eam-msp.crashplanpro.com/client/installers/CrashPlanSmb_${CRASHPLAN_VERSION}_${CRASHPLAN_TIMESTAMP}_${CRASHPLAN_BUILD}_Linux.tgz && \
    ALPINE_GLIBC_BASE_URL='https://github.com/sgerrand/alpine-pkg-glibc/releases/download' && \
    ALPINE_GLIBC_PACKAGE_VERSION='2.29-r0' && \
    ALPINE_GLIBC_BASE_PACKAGE_FILENAME="glibc-${ALPINE_GLIBC_PACKAGE_VERSION}.apk" && \
    ALPINE_GLIBC_BIN_PACKAGE_FILENAME="glibc-bin-${ALPINE_GLIBC_PACKAGE_VERSION}.apk" && \
    ALPINE_GLIBC_I18N_PACKAGE_FILENAME="glibc-i18n-${ALPINE_GLIBC_PACKAGE_VERSION}.apk" && \
    CRASHPLAN_PATH=/usr/local/crashplan && \
    CRASHPLAN_INSTALLER_DEPENDENCIES=expect && \
    apk add --no-cache wget ca-certificates socat gawk bash openssl findutils coreutils procps libstdc++ && \
    apk add --no-cache cpio --repository http://dl-3.alpinelinux.org/alpine/edge/community/ && \
    apk add --no-cache ${CRASHPLAN_INSTALLER_DEPENDENCIES} && \

    # Installing and configuring glibc for alpine
    wget --progress=bar:force \
        'https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub' \
         -O '/etc/apk/keys/sgerrand.rsa.pub' && \
    wget --progress=bar:force \
         "${ALPINE_GLIBC_BASE_URL}/${ALPINE_GLIBC_PACKAGE_VERSION}/${ALPINE_GLIBC_BASE_PACKAGE_FILENAME}" \
         "${ALPINE_GLIBC_BASE_URL}/${ALPINE_GLIBC_PACKAGE_VERSION}/${ALPINE_GLIBC_BIN_PACKAGE_FILENAME}" \
         "${ALPINE_GLIBC_BASE_URL}/${ALPINE_GLIBC_PACKAGE_VERSION}/${ALPINE_GLIBC_I18N_PACKAGE_FILENAME}" && \
    apk add --no-cache \
         "${ALPINE_GLIBC_BASE_PACKAGE_FILENAME}" \
         "${ALPINE_GLIBC_BIN_PACKAGE_FILENAME}" \
         "${ALPINE_GLIBC_I18N_PACKAGE_FILENAME}" && \
    /usr/glibc-compat/bin/localedef --force --inputfile en_US --charmap UTF-8 en_US.UTF-8 && \
    echo 'export LANG=en_US.UTF-8' > /etc/profile.d/locale.sh && \

    # Cleaning up temporary/unneeded files/packages
    sync && \
    rm -rf \
        "${ALPINE_GLIBC_BASE_PACKAGE_FILENAME}" \
        "${ALPINE_GLIBC_BIN_PACKAGE_FILENAME}" \
        "${ALPINE_GLIBC_I18N_PACKAGE_FILENAME}" \
        /var/cache/apk/* \
        /root/.wget-hsts && \

    # Installing CrashPlan for Small Business
    mkdir -p \
        /tmp/crashplan \
        /usr/share/applications \
        /app && \
    cd /tmp/crashplan && \
    echo 'Downloading CrashPlan for Small Business ...' && \
    wget -O- --progress=bar:force ${CRASHPLAN_URL} | tar -xz --strip-components=1 -C /tmp/crashplan && \
    chmod +x /tmp/installation/* && sync && /tmp/installation/crashplan.exp || exit $? && \
    /etc/init.d/crashplan stop || true && \

    # Prepare CrashPlan config files for docker config volume
    /tmp/installation/move_config.sh && \

    # Cleaning up temporary/unneeded files/packages
    sync && \
    cd / && \
    apk update && sync && apk del ${CRASHPLAN_INSTALLER_DEPENDENCIES} && \
    /tmp/installation/trim_install.sh && \
    rm -rf \
        /boot /home /lost+found /media /mnt /run /srv \
        /var/cache/apk/* \
        /root/.wget-hsts \
        /usr/share/applications \
        /tmp/* \
        ${CRASHPLAN_PATH}/*.pid \
        /config

#########################################
## SETUP DOCKER WRAPPER FOR CP PROCESS ##
#########################################
ADD /files /app

# Make some basic tweaks to CP for docker stability/functionality and
# remove docker image build scripts.
RUN chmod +x /app/* && /app/patch_install.sh && rm -f /app/crashplan.exp /app/move_config.sh

#########################################
##              VOLUMES                ##
#########################################
VOLUME [ "/config" ]

#########################################
##            EXPOSE PORTS             ##
#########################################
EXPOSE 4244

WORKDIR /usr/local/crashplan

ENTRYPOINT [ "/app/entrypoint.sh" ]
CMD [ "/app/crashplan.sh" ]
