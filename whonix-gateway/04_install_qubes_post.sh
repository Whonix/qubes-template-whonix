#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

## Copyright (C) 2012 - 2018 ENCRYPTED SUPPORT LP <adrelanos@riseup.net>
## See the file COPYING for copying conditions.

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

## Qubes R3.1 compatibility.
## Can be removed on Qubes R3.2 and above.
## https://github.com/QubesOS/qubes-issues/issues/1174
if [ "$(type -t chroot_cmd)" = "function" ]; then
   chroot_cmd="chroot_cmd"
else
   chroot_cmd="chroot"
fi

mount --bind /dev "${INSTALLDIR}/dev"

aptInstall apt-transport-https

## Install Qubes' repository so dependencies of the qubes-whonix package
## that gets installed by Whonix's build script will be available.
## (Cant be done in '.whonix_prepared', because installQubesRepo's 'mount' does not survive reboots.)
installQubesRepo

## Better to build from stretch-proposed-updates to test the upgrades.
[ -n "$whonix_repository_suite" ] || whonix_repository_suite="stretch-proposed-updates"

[ -n "$whonix_signing_key_fingerprint" ] || whonix_signing_key_fingerprint="916B8D99C38EAF5E8ADC7A2A8D66066A2EEACCDA"
[ -n "$whonix_signing_key_file" ] || whonix_signing_key_file="$BUILDER_DIR/$SRC_DIR/template-whonix/keys/whonix-developer-patrick.asc"
[ -n "$gpg_keyserver" ] || gpg_keyserver="keys.gnupg.net"
[ -n "$whonix_repository_uri" ] || whonix_repository_uri="http://deb.whonix.org"
[ -n "$whonix_repository_components" ] || whonix_repository_components="main"
[ -n "$whonix_repository_apt_line" ] || whonix_repository_apt_line="deb $whonix_repository_uri $whonix_repository_suite $whonix_repository_components"
[ -n "$whonix_repository_temporary_apt_sources_list" ] || whonix_repository_temporary_apt_sources_list="/etc/apt/sources.list.d/whonix_build.list"

if [ "$whonix_signing_key_fingerprint" = "none" ]; then
   info "whonix_signing_key_fingerprint is set to '$whonix_signing_key_fingerprint', therefore apt-key adding as requested."
else
   cat "$whonix_signing_key_file" | $chroot_cmd apt-key add -

   ## Sanity test. apt-key adv would exit non-zero if not exactly that fingerprint in apt's keyring.
   $chroot_cmd apt-key adv --fingerprint "$whonix_signing_key_fingerprint"
fi

echo "$whonix_repository_apt_line" > "${INSTALLDIR}/$whonix_repository_temporary_apt_sources_list"

aptUpdate

[ -n "$DEBDEBUG" ] || export DEBDEBUG="1"
[ -n "$tpo_downloader_debug" ] || export tpo_downloader_debug="1"

if [ -n "$WHONIX_TBB_VERSION" ]; then
    mkdir -p "${INSTALLDIR}/etc/torbrowser.d"
    echo "tbb_version=\"$WHONIX_TBB_VERSION\"" > \
        "${INSTALLDIR}/etc/torbrowser.d/80_template_builder_override.conf"
fi

if [ "${TEMPLATE_FLAVOR}" = "whonix-gateway" ]; then
   aptInstall qubes-whonix-gateway
elif [ "${TEMPLATE_FLAVOR}" = "whonix-workstation" ]; then
   aptInstall qubes-whonix-workstation
else
   error "TEMPLATE_FLAVOR is neither whonix-gateway nor whonix-workstation, it is: ${TEMPLATE_FLAVOR}"
fi

uninstallQubesRepo

rm -f "${INSTALLDIR}/$whonix_repository_temporary_apt_sources_list"

if [ -e "${INSTALLDIR}/etc/apt/sources.list.d/debian.list" ]; then
    info ' Remove original sources.list (Whonix package anon-apt-sources-list \
ships /etc/apt/sources.list.d/debian.list)'
    rm -f "${INSTALLDIR}/etc/apt/sources.list"
fi

if [ -n "$WHONIX_TBB_VERSION" ]; then
    # cleanup override after initial install
    rm -f "${INSTALLDIR}/etc/torbrowser.d/80_template_builder_override.conf"
fi

## Maybe Enable Tor.
if [ "${TEMPLATE_FLAVOR}" == "whonix-gateway" ] && [ "${WHONIX_ENABLE_TOR}" -eq 1 ]; then
    sed -i "s/^#DisableNetwork/DisableNetwork/g" "${INSTALLDIR}/etc/tor/torrc"
fi

## Workaround for Qubes bug:
## 'Debian Template: rely on existing tool for base image creation'
## https://github.com/QubesOS/qubes-issues/issues/1055
updateLocale

## Workaround. ntpdate needs to be removed here, because it can not be removed from
## template_debian/packages_qubes.list, because that would break minimal Debian templates.
## https://github.com/QubesOS/qubes-issues/issues/1102
UWT_DEV_PASSTHROUGH="1" aptRemove ntpdate || true

UWT_DEV_PASSTHROUGH="1" \
   DEBIAN_FRONTEND="noninteractive" \
   DEBIAN_PRIORITY="critical" \
   DEBCONF_NOWARNINGS="yes" \
      $chroot_cmd $eatmydata_maybe \
         apt-get ${APT_GET_OPTIONS} autoremove

## Cleanup.
umount_all "${INSTALLDIR}/" || true
trap - ERR EXIT
trap
