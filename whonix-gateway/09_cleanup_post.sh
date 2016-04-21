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

if [ -x "${INSTALLDIR}/usr/lib/anon-dist/chroot-scripts-post.d/80_cleanup" ]; then
   "${INSTALLDIR}/usr/lib/anon-dist/chroot-scripts-post.d/80_cleanup"
fi
