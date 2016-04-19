#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 -o "$DEBUG" == "1" ]; then
    set -x
fi

source "${SCRIPTSDIR}/vars.sh"
source "${SCRIPTSDIR}/distribution.sh"

## If .prepared_debootstrap has not been completed, don't continue.
exitOnNoFile "${INSTALLDIR}/${TMPDIR}/.prepared_qubes" "prepared_qubes installation has not completed!... Exiting"

#### '--------------------------------------------------------------------------
info ' Trap ERR and EXIT signals and cleanup (umount)'
#### '--------------------------------------------------------------------------
trap cleanup ERR
trap cleanup EXIT

prepareChroot

## TODO
#whonix_build_options=(
#    "--flavor ${TEMPLATE_FLAVOR}"
#    "--kernel linux-image-amd64"
#    "--headers linux-headers-amd64"
#    "--unsafe-io true"

## TODO
# --whonix-repo ${WHONIX_APT_REPOSITORY_OPTS}
# sudo whonix_repository --enable --suite ....................

## TODO: should be done by tb-updater postinst?
#if [ "${TEMPLATE_FLAVOR}" == "whonix-workstation" ] && [ "${WHONIX_INSTALL_TB}" -eq 1 ]; then
#    whonix_build_options+=("--tb closed")
#fi

##### '-------------------------------------------------------------------------
#debug ' Preparing Whonix for installation'
##### '-------------------------------------------------------------------------
#if ! [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_prepared" ]; then
    #info "Preparing Whonix system"

    #aptInstall sudo

    ## TODO
    #### '----------------------------------------------------------------------
    #info ' Adding a user account for Whonix to build with'
    #### '----------------------------------------------------------------------
    #chroot id -u 'user' >/dev/null 2>&1 || \
    #{
        # UID needs match host user to have access to Whonix sources
        #chroot groupadd -f user
        #[ -n "$SUDO_UID" ] && USER_OPTS="-u $SUDO_UID"
        #chroot useradd -g user $USER_OPTS -G sudo,audio -m -s /bin/bash user
        #if [ `chroot id -u user` != 1000 ]; then
            #chroot useradd -g user -u 1000 -M -s /bin/bash user-placeholder
        #fi
    #}

    ## TODO
    #### '----------------------------------------------------------------------
    #info ' Copying additional files required for build'
    #### '----------------------------------------------------------------------
    #copyTree "files"

    # Install Tor browser to /home/user by default. (build-step only)
    #
    # Set tor-browser installation directory.  This can't really be put in
    # 'qubes-whonix' postinst since the value is not static if a custom
    # directory location is chosen.
    #if [ "${TEMPLATE_FLAVOR}" == "whonix-workstation" ] && [ "${WHONIX_INSTALL_TB}" -eq 1 ]; then
        #if [ -n "${WHONIX_INSTALL_TB_DIRECTORY}" ]; then
            #mkdir -p "${INSTALLDIR}/etc/torbrowser.d"
            #echo "tb_home_folder=${WHONIX_INSTALL_TB_DIRECTORY}" > "${INSTALLDIR}/etc/torbrowser.d/40_whonix_build"
        #fi
    #fi

    #touch "${INSTALLDIR}/${TMPDIR}/.whonix_prepared"
#fi


##### '-------------------------------------------------------------------------
#debug ' Installing Whonix code base'
##### '-------------------------------------------------------------------------
#if [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_prepared" ] && ! [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_installed" ]; then
    ## Install Qubes' repository so dependencies of the qubes-whonix package
    ## that gets installed by Whonix's build script will be available.
    ## (Cant be done in '.whonix_prepared', because installQubesRepo's 'mount' does not survive reboots.)
    installQubesRepo

    #### '----------------------------------------------------------------------
    #info ' Create Whonix directory (/home/user/Whonix)'
    #### '----------------------------------------------------------------------
    #if ! [ -d "${INSTALLDIR}/home/user/Whonix" ]; then
        #chroot su user -c 'mkdir -p /home/user/Whonix'
    #fi

    #### '----------------------------------------------------------------------
    #info " Bind Whonix source directory (${BUILDER_DIR}/${SRC_DIR}/Whonix)"
    #### '----------------------------------------------------------------------
    #mount --bind "${BUILDER_DIR}/${SRC_DIR}/Whonix" "${INSTALLDIR}/home/user/Whonix"

    #### '----------------------------------------------------------------------
    info ' mounts...'
    #### '----------------------------------------------------------------------
    mount --bind /dev "${INSTALLDIR}/dev"

    ## Workaround for issue:
    ## sem_open: Permission denied
    ## https://phabricator.whonix.org/T369
    ## Can be removed as soon as Whonix packages as no longer build using faketime.
    #chmod o+w "${INSTALLDIR}/dev/shm"

    #### '----------------------------------------------------------------------
    #info ' Executing whonix_build script now...'
    #### '----------------------------------------------------------------------

    ## Using ~/Whonix/help-steps/whonix_build_one instead of ~/Whonix/whonix_build,
    ## because the --whonix-repo switch in ~/Whonix/whonix_build parser does not
    ## support spaces.
    #chroot \
       #sudo -u user \
          #env \
             #LD_PRELOAD=${LD_PRELOAD:+$LD_PRELOAD:}libeatmydata.so \
             #REPO_PROXY=${REPO_PROXY} \
             #sudo -E ~/Whonix/help-steps/whonix_build_one ${whonix_build_options[@]} || { exit 1; }

    #touch "${INSTALLDIR}/${TMPDIR}/.whonix_installed"
#fi

## TODO
## TODO
## install and install from Whonix repo

## TODO: configurable
## TODO: set to jessie
whonix_repository_suite="developers"

## TODO: configurable
whonix_signing_key_fingerprint="916B8D99C38EAF5E8ADC7A2A8D66066A2EEACCDA"
gpg_keyserver="keys.gnupg.net"
whonix_repository_uri="http://www.whonix.org/download/whonixdevelopermetafiles/internal/"
whonix_repository_components="main"
whonix_repository_apt_line="deb $whonix_repository_uri $whonix_repository_suite $whonix_repository_components"
whonix_repository_temporary_apt_sources_list="/etc/apt/sources.list.d/whonix_build.list"

chroot apt-key adv --keyserver "$gpg_keyserver" --recv-key "$whonix_signing_key_fingerprint"

## Sanity test. apt-key adv would exit non-zero if not exactly that fingerprint in apt's keyring.
chroot apt-key adv --fingerprint "$whonix_signing_key_fingerprint"

echo "$whonix_repository_apt_line" > "${INSTALLDIR}/$whonix_repository_temporary_apt_sources_list"

## TODO: check for
## apt-get
## -o Dir::Etc::sourcelist=/tmp/empty
## -o Dir::Etc::sourceparts=/var/lib/whonix/sources_temp_list.d

## TODO: check for
## -o Acquire::http::Timeout=180
## -o Acquire::ftp::Timeout=180
## -o Acquire::Retries=3

## TODO: check for
## -o APT::Get::force-yes=0
## -o Dpkg::Options::=--force-confnew

## TODO: check for
## -o Dpkg::Options::=--force-unsafe-io

## TODO: check for
## -o Acquire::http::Proxy=http://127.0.0.1:3142

## TODO: check for
## --no-install-recommends

aptUpdate

if [ "${TEMPLATE_FLAVOR}" = "whonix-gateway" ]; then
   aptInstall qubes-whonix-gateway
elif [ "${TEMPLATE_FLAVOR}" = "whonix-workstation" ]; then
   aptInstall qubes-whonix-workstation
else
   error "TEMPLATE_FLAVOR is neither whonix-gateway nor whonix-workstation, it is: ${TEMPLATE_FLAVOR}"
fi

## TODO: required?
## Just in case.
aptUpgrade

##### '-------------------------------------------------------------------------
#debug ' Whonix Post Installation Configurations'
##### '-------------------------------------------------------------------------
#if [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_installed" ] && ! [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_post" ]; then
    uninstallQubesRepo

    ## TODO: No longer required or can be done in postinst script?
    #### '----------------------------------------------------------------------
    #info ' Restore default user UID set to so same in all builds regardless of build host'
    #### '----------------------------------------------------------------------
    #if [ -n "`chroot id -u user-placeholder`" ]; then
        #chroot userdel user-placeholder
        #chroot usermod -u 1000 user
    #fi

    #### '----------------------------------------------------------------------
    info 'Maybe Enable Tor'
    #### '----------------------------------------------------------------------
    if [ "${TEMPLATE_FLAVOR}" == "whonix-gateway" ] && [ "${WHONIX_ENABLE_TOR}" -eq 1 ]; then
        sed -i "s/^#DisableNetwork/DisableNetwork/g" "${INSTALLDIR}/etc/tor/torrc"
    fi

if [ -e "${INSTALLDIR}/etc/apt/sources.list.d/debian.list" ]; then
    info ' Remove original sources.list (Whonix package anon-apt-sources-list \
ships /etc/apt/sources.list.d/debian.list)'
    rm -f "${INSTALLDIR}/etc/apt/sources.list"
fi

    #touch "${INSTALLDIR}/${TMPDIR}/.whonix_post"
#fi

## Workaround for Qubes bug:
## 'Debian Template: rely on existing tool for base image creation'
## https://github.com/QubesOS/qubes-issues/issues/1055
updateLocale

##### '-------------------------------------------------------------------------
debug ' Whonix post installation cleanup'
##### '-------------------------------------------------------------------------

## Can be removed when https://github.com/marmarek/qubes-builder-debian/pull/18 was merged.
UWT_DEV_PASSTHROUGH="1" aptRemove chrony || true

## Workaround. ntpdate needs to be removed here, because it can not be removed from
## template_debian/packages_qubes.list, because that would break minimal Debian templates.
## https://github.com/QubesOS/qubes-issues/issues/1102
UWT_DEV_PASSTHROUGH="1" aptRemove ntpdate || true

UWT_DEV_PASSTHROUGH="1" \
   DEBIAN_FRONTEND="noninteractive" \
   DEBIAN_PRIORITY="critical" \
   DEBCONF_NOWARNINGS="yes" \
      chroot $eatmydata_maybe \
         apt-get ${APT_GET_OPTIONS} autoremove

#### '--------------------------------------------------------------------------
info ' Cleanup'
#### '--------------------------------------------------------------------------
umount_all "${INSTALLDIR}/" || true
trap - ERR EXIT
trap
