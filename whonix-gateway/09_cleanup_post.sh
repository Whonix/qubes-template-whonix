#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

#
# The Qubes OS Project, http://www.qubes-os.org
#
# Copyright (C) 2012 - 2025 ENCRYPTED SUPPORT LLC <adrelanos@whonix.org>
# Copyright (C) 2015 Jason Mehring <nrgaway@gmail.com>
# Copyright (C) 2022 Frederic Pierret <frederic@invisiblethingslab.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: GPL-3.0-or-later

if [ "$DEBUG" == "1" ]; then
    set -x
fi

true "$0: START"

#
# Handle legacy builder
#

if [ -n "${SCRIPTSDIR}" ]; then
  TEMPLATE_CONTENT_DIR="${SCRIPTSDIR}"
fi

if [ -n "${INSTALLDIR}" ]; then
  INSTALL_DIR="${INSTALLDIR}"
fi

# shellcheck source=qubesbuilder/plugins/template_debian/vars.sh
source "${TEMPLATE_CONTENT_DIR}/vars.sh"
# shellcheck source=qubesbuilder/plugins/template_debian/distribution.sh
source "${TEMPLATE_CONTENT_DIR}/distribution.sh"

##### '-------------------------------------------------------------------------
debug 'Whonix chroot-scripts'
##### '-------------------------------------------------------------------------

## Check which chroot scripts we got.
chroot_cmd run-parts --verbose --test "/usr/libexec/initializer-dist/chroot-scripts-post.d/"

## Run the chroot scripts.
chroot_cmd run-parts --verbose --exit-on-error "/usr/libexec/initializer-dist/chroot-scripts-post.d/"

debug "$0: END"
