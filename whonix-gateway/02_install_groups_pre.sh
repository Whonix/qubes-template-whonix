#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

# ==============================================================================
#                           WHONIX 10 - WIP NOTES
# ==============================================================================
# 
# TODO - TEMP TEST:
# ------------------------------------------------------------------------------
# -
#
# TODO - EXPERIMENT:
# ------------------------------------------------------------------------------
# -
#
# TODO - FIX:
# ------------------------------------------------------------------------------
# - dialog boxes partial display as semi-transparent (wheezy + jessie)
#   - test to see if that is still case with gnome enable workstation
#   - possible QT or TrollTech.conf issue?
#
# WHONIX RELATED BUGS:
# ------------------------------------------------------------------------------
# -
#
# REPAIR AFTER SUCCESSFUL BUILDS:
# ------------------------------------------------------------------------------
# -
# 
# ==============================================================================

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

if ! [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_prepared_groups" ]; then
    #### '----------------------------------------------------------------------
    info ' Installing extra packages in packages_whonix.list file'
    #### '----------------------------------------------------------------------
    installPackages packages_whonix.list

    #### '----------------------------------------------------------------------
    info ' Installing extra packages from Whonix 30_dependencies'
    #### '----------------------------------------------------------------------
    source "${WHONIX_DIR}/buildconfig.d/30_dependencies"
    aptInstall ${whonix_build_script_build_dependency}

    touch "${INSTALLDIR}/${TMPDIR}/.whonix_prepared_groups"
fi


# ==============================================================================
# chroot Whonix build script
# ==============================================================================
read -r -d '' WHONIX_BUILD_SCRIPT <<'EOF' || true
################################################################################
# This script is executed from chroot most likely as the user `user`
# 
# - The purpose is to do a few pre-fixups that are directly related to whonix
#   build process
# - Then, finally, call `whonix_build_post` as sudo with a clean (no) ENV
#
################################################################################

# Pre Fixups
sudo mkdir -p /boot/grub2
sudo touch /boot/grub2/grub.cfg
sudo mkdir -p /boot/grub
sudo touch /boot/grub/grub.cfg
sudo mkdir --parents --mode=g+rw "/tmp/uwt"

# Whonix seems to re-install sysvinit even though there is a hold
# on the package.  Things seem to work anyway. BUT hopfully the
# hold on grub* don't get removed
sudo apt-mark hold sysvinit
sudo apt-mark hold grub-pc grub-pc-bin grub-common grub2-common

# Whonix expects haveged to be started
# ------------------------------------------------------------------------------
sudo /etc/init.d/haveged start

# Use sudo with clean ENV to build Whonix; any ENV options will be set there
# ------------------------------------------------------------------------------
sudo ~/whonix_build_post $@
EOF

# ==============================================================================
# chroot Whonix post build script
# ==============================================================================
read -r -d '' WHONIX_BUILD_SCRIPT_POST <<'EOF' || true
#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

# Prevents Whonix makefile use of shared memory 'sem_open: Permission denied'
# ------------------------------------------------------------------------------
echo tmpfs /dev/shm tmpfs defaults 0 0 >> /etc/fstab
mount /dev/shm

# =============================================================================
# WHONIX BUILD COMMAND
# =============================================================================
pushd /home/user/Whonix
/home/user/Whonix/whonix_build \
    --flavor $1 \
    -- \
    --build \
    --arch amd64 \
    --kernel linux-image-amd64 \
    --headers linux-headers-amd64 \
    --freshness current \
    --target root \
    --report minimal \
    --verifiable minimal \
    --allow-uncommitted true \
    --allow-untagged true \
    --sanity-tests false || { exit 1; }
popd
EOF


# Some Additional Whonix build options
# ====================================
#    --tb close  # Install tor-browser \
#    --allow-uncommitted true \
#    --allow-untagged true \
#    --testing-frozen-sources  # Jessie; no current sources \


##### '-------------------------------------------------------------------------
debug ' Preparing Whonix for installation'
##### '-------------------------------------------------------------------------
if [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_prepared_groups" ] && ! [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_prepared" ]; then
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
    info ' Faking grub installation since Whonix has depends on grub-pc'
    #### '----------------------------------------------------------------------
    mkdir -p "${INSTALLDIR}/boot/grub"
    cp "${INSTALLDIR}/usr/lib/grub/i386-pc/"* "${INSTALLDIR}/boot/grub"
    rm -f "${INSTALLDIR}/usr/sbin/update-grub"
    chroot ln -fs /bin/true /usr/sbin/update-grub

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
    info ' Installing Whonix build scripts'
    #### '----------------------------------------------------------------------
    echo "${WHONIX_BUILD_SCRIPT_POST}" > "${INSTALLDIR}/home/user/whonix_build_post"
    chmod 0755 "${INSTALLDIR}/home/user/whonix_build_post"

    echo "${WHONIX_BUILD_SCRIPT}" > "${INSTALLDIR}/home/user/whonix_build"
    chmod 0755 "${INSTALLDIR}/home/user/whonix_build"

    #### '----------------------------------------------------------------------
    info ' Removing apt-listchanges if it exists,so no prompts appear'
    #### '----------------------------------------------------------------------
    #      Whonix does not handle this properly, but aptInstall packages will
    aptRemove apt-listchanges || true

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

    touch "${INSTALLDIR}/${TMPDIR}/.whonix_prepared"
fi


##### '-------------------------------------------------------------------------
debug ' Installing Whonix code base'
##### '-------------------------------------------------------------------------
if [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_prepared" ] && ! [ -f "${INSTALLDIR}/${TMPDIR}/.whonix_installed" ]; then
    if ! [ -d "${INSTALLDIR}/home/user/Whonix" ]; then
        chroot su user -c 'mkdir /home/user/Whonix'
    fi

    # XXX: TODO: Need to get from ENV $WHONIX_DIR as we can't always be sure where dir is
    mount --bind "../Whonix" "${INSTALLDIR}/home/user/Whonix"

    if [ "${TEMPLATE_FLAVOR}" == "whonix-gateway" ]; then
        BUILD_TYPE="whonix-gateway"
    elif [ "${TEMPLATE_FLAVOR}" == "whonix-workstation" ]; then
        BUILD_TYPE="whonix-workstation"
    else
        error "Incorrent Whonix type \"${TEMPLATE_FLAVOR}\" selected.  Not building Whonix modules"
        error "You need to set TEMPLATE_FLAVOR environment variable to either"
        error "whonix-gateway OR whonix-workstation"
        exit 1
    fi

    # Whonix needs /dev/pts mounted during build
    mount --bind /dev "${INSTALLDIR}/dev"
    mount --bind /dev/pts "${INSTALLDIR}/dev/pts"

    # Enable for logging...
    # XXX: Remove static reference and store in template-whonix $DIR
    #BUILD_LOG=/home/user/qubes/qubes-src/template-whonix/whonix.log

    info 'Executing whonix_build script now...'
    if [ "x${BUILD_LOG}" != "x" ]; then
        chroot su user -c "cd ~; ./whonix_build ${BUILD_TYPE} ${DIST}" 3>&2 2>&1 | tee -a ${BUILD_LOG} || { exit 1; }
    else
        chroot su user -c "cd ~; ./whonix_build ${BUILD_TYPE} ${DIST}" || { exit 1; }
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
    info ' Temporarily retore original hosts for remainder of install process'
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
    info ' Enable some aliases in .bashrc'
    #### '----------------------------------------------------------------------
    sed -i "s/^# export/export/g" "${INSTALLDIR}/root/.bashrc"
    sed -i "s/^# eval/eval/g" "${INSTALLDIR}/root/.bashrc"
    sed -i "s/^# alias/alias/g" "${INSTALLDIR}/root/.bashrc"
    sed -i "s/^#force_color_prompt/force_color_prompt/g" "${INSTALLDIR}/home/user/.bashrc"
    sed -i "s/#alias/alias/g" "${INSTALLDIR}/home/user/.bashrc"
    sed -i "s/alias l='ls -CF'/alias l='ls -l'/g" "${INSTALLDIR}/home/user/.bashrc"

    #### '----------------------------------------------------------------------
    info ' Remove apt-cacher-ng'
    #### '----------------------------------------------------------------------
    chroot service apt-cacher-ng stop || :
    chroot update-rc.d apt-cacher-ng disable || :
    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
        chroot apt-get.anondist-orig -y --force-yes remove --purge apt-cacher-ng

    #### '----------------------------------------------------------------------
    info ' Remove original sources.list (Whonix copied them to .../debian.list)'
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
