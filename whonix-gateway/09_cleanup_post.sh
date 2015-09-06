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

#### '--------------------------------------------------------------------------
info ' Removing files created during installation that are no longer required'
#### '--------------------------------------------------------------------------
rm -rf "${INSTALLDIR}/home.orig/user/Whonix"
rm -rf "${INSTALLDIR}/home.orig/user/whonix_binary"
rm -f "${INSTALLDIR}/etc/sudoers.d/whonix-build"
rm -f "${INSTALLDIR}/etc/torbrowser.d/40_whonix_build"
rm -f "${TMPDIR}/etc/sudoers.d/whonix-build"
