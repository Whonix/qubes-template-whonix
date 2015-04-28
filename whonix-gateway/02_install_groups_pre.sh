#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

# ==============================================================================
#                           WHONIX 11 - WIP NOTES
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
# 1700_install-packages:450 --> "$WHONIX_SOURCE_HELP_STEPS_FOLDER/remove-local-temp-apt-repo"
# INFO: Setting... export UWT_DEV_PASSTHROUGH="1"
# INFO: Variable anon_dist_build_version was already set to: 11.0.0.0.1
# /home/user/Whonix/help-steps/pre: line 20: error_: command not found
# ...
# + true 'INFO: Currently running script: /home/user/Whonix/help-steps/unprevent-daemons-from-starting '
# + true 'INFO: Currently running script: /home/user/Whonix/help-steps/unchroot-raw '
# + true 'INFO: Skipping script, because ANON_BUILD_INSTALL_TO_ROOT=1: /home/user/Whonix/help-steps/unmount-raw'
# + true 'INFO: Currently running script: ././build-steps.d/2300_run-chroot-scripts-post-d '
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


# ==============================================================================
# TODO: Confirm if these fixups still apply to Whonix 11
# ==============================================================================


# Whonix expects haveged to be started
# XXX: What to do when init file gone since can not start systed in chroot ENV?
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


# =============================================================================
# `TO KEEP` COMMENTED OUT CONFIGURATIONS
# =============================================================================
# Make sure we clear Qubes overrides of these vars
# - These will be kept for future reference in case module is re-factored
#   differently and would be required if ENV was passed via sudo
#export GENMKFILE_INCLUDE_FILE_MAIN=
#export GENMKFILE_BOOTSTRAP=


# =============================================================================
# `TO REMOVE` CONFIGURATIONS + HACK THAT WILL MOST LIKELY BE REMOVED
# =============================================================================
# Whonix 11 Hacks (stretch does not exist)
# XXX: Should be fixed in next tag release
# ------------------------------------------------------------------------------
export whonix_build_apt_newer_release_codename="jessie"

# Disable lintian; cause too many build errors
# XXX: Will be fixed at some point when lintian error have been fixed for jessie
# ------------------------------------------------------------------------------
# `sed` only needed till next tag release
sudo sed -i "s/make_use_lintian=\"true\"/make_use_lintian=\"false\"/g" "/home/user/Whonix/build-steps.d/1200_create-debian-packages"
export make_use_lintian="true"


# =============================================================================
# `REQUIRED` CONFIGURATIONS
# =============================================================================
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
    --freshness current \
    --target root \
    --report minimal \
    --verifiable minimal \
    --allow-uncommitted true \
    --allow-untagged true \
    --sanity-tests false || { exit 1; }
popd
EOF


# Whonix11 removed for now...
# ====================================
#    --kernel linux-image-amd64 \
#    --headers linux-headers-amd64 \
#
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
        su $(logname) -c "git submodule update --init --recursive";
    }
    popd

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
    debug 'XXX: Whonix11 HACK since we running all sections without conditions'
    debug '     and we are deleting and linking interfaces below'
    debug 'XXX: Remove interfaces from files directory when this hack not needed'
    #### '----------------------------------------------------------------------
    rm -f "${INSTALLDIR}/etc/network/interfaces"

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

    info 'Executing whonix_build script now...'
    chroot su user -c "cd ~; ./whonix_build ${BUILD_TYPE} ${DIST}" || { exit 1; }

#    # Issues with logger; revert back to no logging for now
#    warn 'Executing whonix_build script now...'
#    # XXX: Remove static reference and store in template-whonix $DIR
#    BUILD_LOG=/home/user/qubes/qubes-src/template-whonix/whonix.log
#    chroot su user -c "cd ~; ./whonix_build ${BUILD_TYPE} ${DIST}" 3>&2 2>&1 | tee -a ${BUILD_LOG} || { exit 1; }

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
