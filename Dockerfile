FROM alpine:3.9

# Here we install GNU libc (aka glibc) and set en_US.UTF-8 locale as default.
RUN ALPINE_GLIBC_BASE_URL="https://github.com/sgerrand/alpine-pkg-glibc/releases/download" && \
    ALPINE_GLIBC_PACKAGE_VERSION="2.29-r0" && \
    ALPINE_GLIBC_BASE_PACKAGE_FILENAME="glibc-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    ALPINE_GLIBC_BIN_PACKAGE_FILENAME="glibc-bin-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    ALPINE_GLIBC_I18N_PACKAGE_FILENAME="glibc-i18n-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    apk add --no-cache wget ca-certificates socat && \
    wget --progress=bar:force \
        "https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub" \
         -O "/etc/apk/keys/sgerrand.rsa.pub" && \
    wget --progress=bar:force \
         "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
         "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
         "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    apk add --no-cache \
         "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
         "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
         "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    /usr/glibc-compat/bin/localedef --force --inputfile en_US --charmap UTF-8 en_US.UTF-8 && \
    echo "export LANG=en_US.UTF-8" > /etc/profile.d/locale.sh && \
    rm "/root/.wget-hsts" && \
    rm \
       "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
       "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
       "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME"

#########################################
##        ENVIRONMENTAL CONFIG         ##
#########################################
# Set correct environment variables
ENV LC_ALL=en_US.UTF-8      \
    LANG=en_US.UTF-8        \
    LANGUAGE=en_US.UTF-8

#########################################
##         RUN INSTALL SCRIPT          ##
#########################################
ADD /files /tmp/installation

# Increase max file watches
# ADD /files/installation/60-max-user-watches.conf /etc/sysctl.d/60-max-user-watches.conf

RUN CRASHPLAN_VERSION=6.9.0 && \
    CRASHPLAN_TIMESTAMP=1525200006690 && \
    CRASHPLAN_BUILD=827 && \
    export CRASHPLAN_URL=https://web-eam-msp.crashplanpro.com/client/installers/CrashPlanSmb_${CRASHPLAN_VERSION}_${CRASHPLAN_TIMESTAMP}_${CRASHPLAN_BUILD}_Linux.tgz && \
    chmod +x /tmp/installation/install.sh && \
    sync && \
    /tmp/installation/install.sh ${CRASHPLAN_URL} && \
    rm -rf /tmp/installation

#########################################
##              VOLUMES                ##
#########################################
VOLUME [ "/var/crashplan" ]

#########################################
##            EXPOSE PORTS             ##
#########################################
EXPOSE 4244

WORKDIR /usr/local/crashplan

ENTRYPOINT ["/entrypoint.sh"]
CMD [ "/crashplan.sh" ]
