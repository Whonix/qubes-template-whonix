#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 -o "$DEBUG" == "1" ]; then
    set -x
fi

set -o pipefail

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
    "--"
    "--build"
    "--arch amd64"
    "--freshness current"
    "--target qubes"
    "--kernel linux-image-amd64"
    "--headers linux-headers-amd64"
    "--unsafe-io true"
    "--report minimal"
    "--verifiable minimal"
    "--allow-uncommitted true"
    "--allow-untagged true"
    "--sanity-tests false"
)

if [ "${TEMPLATE_FLAVOR}" == "whonix-workstation" ] && [ "${WHONIX_INSTALL_TB}" -eq 1 ]; then
    whonix_build_options+=("--tb closed")
fi


# ==============================================================================
# chroot Whonix build script
# ==============================================================================
read -r -d '' WHONIX_BUILD_SCRIPT <<EOF || true
#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

# ------------------------------------------------------------------------------
# Prevents Whonix makefile use of shared memory 'sem_open: Permission denied'
# ------------------------------------------------------------------------------
sudo mount -t tmpfs tmpfs /dev/shm

# =============================================================================
# WHONIX BUILD COMMAND
# =============================================================================
#$eatmydata_maybe /home/user/Whonix/whonix_build

pushd ~/Whonix

env \
   LD_PRELOAD=${LD_PRELOAD:+$LD_PRELOAD:}libeatmydata.so \
   REPO_PROXY=${REPO_PROXY} \
      sudo -E ~/Whonix/whonix_build ${whonix_build_options[@]} || { exit 1; }

popd
EOF

##### '-------------------------------------------------------------------------
debug ' Preparing Whonix for installation'
##### '-------------------------------------------------------------------------
if ! [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_prepared" ]; then
    info "Preparing Whonix system"

    #### '----------------------------------------------------------------------
    info ' Initializing Whonix submodules'
    #### '----------------------------------------------------------------------
    pushd "${WHONIX_DIR}"
    {
        su $(logname || echo $SUDO_USER) -c "git submodule update --init --recursive";
    }
    popd

    #### '----------------------------------------------------------------------
    info ' Add items to /etc/skel'
    #### '----------------------------------------------------------------------
    mkdir -p "${INSTALLDIR}/etc/skel/bin"
    mkdir -p "${INSTALLDIR}/etc/skel/opt"

    #### '----------------------------------------------------------------------
    info ' Adding a user account for Whonix to build with'
    #### '----------------------------------------------------------------------
    chroot id -u 'user' >/dev/null 2>&1 || \
    {
        # UID needs match host user to have access to Whonix sources
        chroot groupadd -f user
        [ -n "$SUDO_UID" ] && USER_OPTS="-u $SUDO_UID"
        chroot useradd -g user $USER_OPTS -G sudo,audio -m -s /bin/bash user
        if [ `chroot id -u user` != 1000 ]; then
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
    info ' Installing Whonix build scripts'
    #### '----------------------------------------------------------------------
    echo "${WHONIX_BUILD_SCRIPT_PRE}" > "${INSTALLDIR}/home/user/whonix_build_pre"
    chmod 0755 "${INSTALLDIR}/home/user/whonix_build_pre"
    cat "${INSTALLDIR}/home/user/whonix_build_pre"

    echo "${WHONIX_BUILD_SCRIPT}" > "${INSTALLDIR}/home/user/whonix_build"
    chmod 0755 "${INSTALLDIR}/home/user/whonix_build"

    #### '----------------------------------------------------------------------
    info ' Bind /dev/pts for build'
    #### '----------------------------------------------------------------------
    mount --bind /dev "${INSTALLDIR}/dev"
    mount --bind /dev/pts "${INSTALLDIR}/dev/pts"

    #### '----------------------------------------------------------------------
    info 'Executing whonix_build script now...'
    #### '----------------------------------------------------------------------
    if [ "x${BUILD_LOG}" != "x" ]; then
        chroot sudo -u user /home/user/whonix_build 3>&2 2>&1 | tee -a ${BUILD_LOG} || { exit 1; }
    else
        chroot sudo -u user /home/user/whonix_build || { exit 1; }
    fi

    touch "${INSTALLDIR}/${TMPDIR}/.whonix_installed"
fi


##### '-------------------------------------------------------------------------
debug ' Whonix Post Installation Configurations'
##### '-------------------------------------------------------------------------
if [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_installed" ] && ! [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_post" ]; then

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
    if [ -n "`chroot id -u user-placeholder`" ]; then
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
    info ' Enable some aliases in .bashrc'
    #### '----------------------------------------------------------------------
    sed -i "s/^# export/export/g" "${INSTALLDIR}/root/.bashrc"
    sed -i "s/^# eval/eval/g" "${INSTALLDIR}/root/.bashrc"
    sed -i "s/^# alias/alias/g" "${INSTALLDIR}/root/.bashrc"
    sed -i "s/^#force_color_prompt/force_color_prompt/g" "${INSTALLDIR}/home/user/.bashrc"
    sed -i "s/#alias/alias/g" "${INSTALLDIR}/home/user/.bashrc"
    sed -i "s/alias l='ls -CF'/alias l='ls -l'/g" "${INSTALLDIR}/home/user/.bashrc"

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
