#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 -o "$DEBUG" == "1" ]; then
    set -x
fi

source "${SCRIPTSDIR}/vars.sh"
source "${SCRIPTSDIR}/distribution.sh"

##### '-------------------------------------------------------------------------
debug ' Installing and building Whonix'
##### '-------------------------------------------------------------------------


#### '--------------------------------------------------------------------------
info ' Trap ERR and EXIT signals and cleanup (umount)'
#### '--------------------------------------------------------------------------
trap cleanup ERR
trap cleanup EXIT

#### '----------------------------------------------------------------------
info ' Setting whonix build options'
#### '----------------------------------------------------------------------
whonix_build_options=(
    "--flavor ${TEMPLATE_FLAVOR}"
    "--build"
    "--arch amd64"
    "--freshness current"
    "--target qubes"
    "--kernel linux-image-amd64"
    "--headers linux-headers-amd64"
    "--unsafe-io true"
    "--report minimal"
    "--verifiable false"
    "--allow-uncommitted true"
    "--allow-untagged true"
    "--sanity-tests false"
)

whonix_build_options+=("--whonix-repo ${WHONIX_APT_REPOSITORY_OPTS}")

if [ "${TEMPLATE_FLAVOR}" == "whonix-workstation" ] && [ "${WHONIX_INSTALL_TB}" -eq 1 ]; then
    whonix_build_options+=("--tb closed")
fi

##### '-------------------------------------------------------------------------
debug ' Preparing Whonix for installation'
##### '-------------------------------------------------------------------------
if ! [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_prepared" ]; then
    info "Preparing Whonix system"

    aptInstall sudo

    #### '----------------------------------------------------------------------
    info ' Adding a user account for Whonix to build with'
    #### '----------------------------------------------------------------------
    chroot id -u 'user' >/dev/null 2>&1 || \
    {
        # UID needs match host user to have access to Whonix sources
        chroot groupadd -f user
        [ -n "$SUDO_UID" ] && USER_OPTS="-u $SUDO_UID"
        chroot useradd -g user $USER_OPTS -G sudo,audio -m -s /bin/bash user
        if [ "$(chroot id -u user)" != 1000 ]; then
            chroot useradd -g user -u 1000 -M -s /bin/bash user-placeholder
        fi
    }

    #### '----------------------------------------------------------------------
    debug 'XXX: Whonix10/11 HACK'
    #### '----------------------------------------------------------------------
    rm -f "${INSTALLDIR}/etc/network/interfaces"
    cat > "${INSTALLDIR}/etc/network/interfaces" <<'EOF'
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d
EOF

    #### '----------------------------------------------------------------------
    info ' Copying additional files required for build'
    #### '----------------------------------------------------------------------
    copyTree "files"

    # Install Tor browser to /home/user by default. (build-step only)
    #
    # Set tor-browser installation directory.  This can't really be put in
    # 'qubes-whonix' postinst since the value is not static if a custom
    # directory location is chosen.
    if [ "${TEMPLATE_FLAVOR}" == "whonix-workstation" ] && [ "${WHONIX_INSTALL_TB}" -eq 1 ]; then
        if [ -n "${WHONIX_INSTALL_TB_DIRECTORY}" ]; then
            mkdir -p "${INSTALLDIR}/etc/torbrowser.d"
            echo "tb_home_folder=${WHONIX_INSTALL_TB_DIRECTORY}" > "${INSTALLDIR}/etc/torbrowser.d/40_whonix_build"
        fi
    fi

    touch "${INSTALLDIR}/${TMPDIR}/.whonix_prepared"
fi


##### '-------------------------------------------------------------------------
debug ' Installing Whonix code base'
##### '-------------------------------------------------------------------------
if [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_prepared" ] && ! [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_installed" ]; then
    ## Install Qubes' repository so dependencies of the qubes-whonix package
    ## that gets installed by Whonix's build script will be available.
    ## (Cant be done in '.whonix_prepared', because installQubesRepo's 'mount' does not survive reboots.)
    installQubesRepo

    #### '----------------------------------------------------------------------
    info ' Create Whonix directory (/home/user/Whonix)'
    #### '----------------------------------------------------------------------
    if ! [ -d "${INSTALLDIR}/home/user/Whonix" ]; then
        chroot su user -c 'mkdir -p /home/user/Whonix'
    fi

    #### '----------------------------------------------------------------------
    info " Bind Whonix source directory (${BUILDER_DIR}/${SRC_DIR}/Whonix)"
    #### '----------------------------------------------------------------------
    mount --bind "${BUILDER_DIR}/${SRC_DIR}/Whonix" "${INSTALLDIR}/home/user/Whonix"

    #### '----------------------------------------------------------------------
    info ' mounts...'
    #### '----------------------------------------------------------------------
    mount --bind /dev "${INSTALLDIR}/dev"

    ## Workaround for issue:
    ## sem_open: Permission denied
    ## https://phabricator.whonix.org/T369
    ## Can be removed as soon as Whonix packages as no longer build using faketime.
    chmod o+w "${INSTALLDIR}/dev/shm"

    #### '----------------------------------------------------------------------
    info ' Executing whonix_build script now...'
    #### '----------------------------------------------------------------------

    ## Using ~/Whonix/help-steps/whonix_build_one instead of ~/Whonix/whonix_build,
    ## because the --whonix-repo switch in ~/Whonix/whonix_build parser does not
    ## support spaces.
    chroot sudo -u user \
       env \
          LD_PRELOAD=${LD_PRELOAD:+$LD_PRELOAD:}libeatmydata.so \
          REPO_PROXY=${REPO_PROXY} \
          sudo -E ~/Whonix/help-steps/whonix_build_one ${whonix_build_options[@]} || { exit 1; }

    touch "${INSTALLDIR}/${TMPDIR}/.whonix_installed"
fi


##### '-------------------------------------------------------------------------
debug ' Whonix Post Installation Configurations'
##### '-------------------------------------------------------------------------
if [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_installed" ] && ! [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_post" ]; then
    uninstallQubesRepo

    #### '----------------------------------------------------------------------
    info ' Restoring original network interfaces'
    #### '----------------------------------------------------------------------
    pushd "${INSTALLDIR}/etc/network"
    {
        if [ -e 'interfaces.backup' ]; then
            rm -f interfaces;
            ln -s interfaces.backup interfaces;
        fi
    }
    popd

    #### '----------------------------------------------------------------------
    info ' Temporarily restore original resolv.conf for remainder of install process'
    info ' (Will be restored back in jessie+whonix/04_qubes_install_post.sh)'
    #### '----------------------------------------------------------------------
    pushd "${INSTALLDIR}/etc"
    {
        if [ -e 'resolv.conf.backup' ]; then
            rm -f resolv.conf;
            cp -p resolv.conf.backup resolv.conf;
        fi
    }
    popd

    #### '----------------------------------------------------------------------
    info ' Temporarily restore original hosts for remainder of install process'
    info ' (Will be restored on initial boot)'
    #### '----------------------------------------------------------------------
    pushd "${INSTALLDIR}/etc"
    {
        if [ -e 'hosts.anondist-orig' ]; then
            rm -f hosts;
            cp -p hosts.anondist-orig hosts;
        fi
    }
    popd

    #### '----------------------------------------------------------------------
    info ' Restore default user UID set to so same in all builds regardless of build host'
    #### '----------------------------------------------------------------------
    if [ -n "$(chroot id -u user-placeholder)" ]; then
        chroot userdel user-placeholder
        chroot usermod -u 1000 user
    fi

    #### '----------------------------------------------------------------------
    info 'Maybe Enable Tor'
    #### '----------------------------------------------------------------------
    if [ "${TEMPLATE_FLAVOR}" == "whonix-gateway" ] && [ "${WHONIX_ENABLE_TOR}" -eq 1 ]; then
        sed -i "s/^#DisableNetwork/DisableNetwork/g" "${INSTALLDIR}/etc/tor/torrc"
    fi

    #### '----------------------------------------------------------------------
    info ' Remove original sources.list (Whonix package anon-apt-sources-list \
ships /etc/apt/sources.list.d/debian.list)'
    #### '----------------------------------------------------------------------
    rm -f "${INSTALLDIR}/etc/apt/sources.list"

    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
        chroot apt-get.anondist-orig update

    touch "${INSTALLDIR}/${TMPDIR}/.whonix_post"
fi


##### '-------------------------------------------------------------------------
debug ' Temporarily restore original apt-get for remainder of install process'
##### '-------------------------------------------------------------------------
pushd "${INSTALLDIR}/usr/bin"
{
    rm -f apt-get;
    cp -p apt-get.anondist-orig apt-get;
}
popd

#### '----------------------------------------------------------------------
info ' Cleanup'
#### '----------------------------------------------------------------------
trap - ERR EXIT
trap
