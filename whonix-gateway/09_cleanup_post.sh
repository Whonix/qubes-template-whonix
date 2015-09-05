#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

if [ "$VERBOSE" -ge 2 -o "$DEBUG" == "1" ]; then
    set -x
fi

source "${SCRIPTSDIR}/vars.sh"
source "${SCRIPTSDIR}/distribution.sh"

##### '-------------------------------------------------------------------------
debug ' Whonix post installation cleanup'
##### '-------------------------------------------------------------------------

## Can be removed when https://github.com/marmarek/qubes-builder-debian/pull/18 was merged.
aptRemove chrony

## Workaround. ntpdate needs to be removed here, because it can not be removed from
## template_debian/packages_qubes.list, because that would break minimal Debian templates.
## https://github.com/QubesOS/qubes-issues/issues/1102
aptRemove ntpdate
DEBIAN_FRONTEND="noninteractive" DEBIAN_PRIORITY="critical" DEBCONF_NOWARNINGS="yes" \
        chroot $eatmydata_maybe apt-get ${APT_GET_OPTIONS} autoremove

#### '--------------------------------------------------------------------------
info ' Restoring Whonix apt-get'
#### '--------------------------------------------------------------------------
pushd "${INSTALLDIR}/usr/bin"
{
    rm -f apt-get;
    cp -p apt-get.anondist apt-get;
}
popd

#### '--------------------------------------------------------------------------
info ' Restoring Whonix resolv.conf'
#### '--------------------------------------------------------------------------
pushd "${INSTALLDIR}/etc"
{
    rm -f resolv.conf;
    cp -p resolv.conf.anondist resolv.conf;
}
popd

#### '--------------------------------------------------------------------------
info ' Removing files created during installation that are no longer required'
#### '--------------------------------------------------------------------------
rm -rf "${INSTALLDIR}/home.orig/user/Whonix"
rm -rf "${INSTALLDIR}/home.orig/user/whonix_binary"
rm -f "${INSTALLDIR}/etc/sudoers.d/whonix-build"
rm -f "${INSTALLDIR}/etc/torbrowser.d/40_whonix_build"
rm -f "${TMPDIR}/etc/sudoers.d/whonix-build"
