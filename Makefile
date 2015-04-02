#
# The Qubes OS Project, http://www.qubes-os.org
#
# Copyright (C) 2014  Jason Mehring <nrgaway@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
#

all:
	@true

# Prompt to confirm import of Whonix keys
.PHONY: import-whonix-keys
import-whonix-keys:
	export GNUPGHOME="$(BUILDER_DIR)/keyrings/git"; \
	if ! gpg --list-keys 916B8D99C38EAF5E8ADC7A2A8D66066A2EEACCDA >/dev/null 2>&1; then \
	    echo "**********************************************************"; \
	    echo "*** You've selected Whonix build, this will import     ***"; \
	    echo "*** Whonix code signing key to qubes-builder, globally ***"; \
	    echo "**********************************************************"; \
	    echo -n "Do you want to continue? (y/N) "; \
	    read answer; \
	    [ "$$answer" == "y" ] || exit 1; \
	    echo '916B8D99C38EAF5E8ADC7A2A8D66066A2EEACCDA:6:' | gpg --import-ownertrust; \
	    gpg --import $(BUILDER_DIR)/$(SRC_DIR)/template-whonix/keys/whonix-developer-patrick.asc; \
	    gpg --list-keys; \
	fi; \
	touch "$$GNUPGHOME/pubring.gpg"

WHONIX_COMPONENTS := 

# qubes-whonix
# -----------------------------------------------------------------------------
#export GIT_URL_qubes_whonix = https://github.com/Whonix/qubes-whonix.git
#export BRANCH_qubes_whonix = 9.6.2

# [UPSTREAM REPO]
export GIT_URL_qubes_whonix = https://github.com/nrgaway/qubes-whonix.git
export BRANCH_qubes_whonix = master
WHONIX_COMPONENTS += qubes-whonix

# Whonix
# -----------------------------------------------------------------------------
export GIT_URL_Whonix = https://github.com/Whonix/Whonix.git
export BRANCH_Whonix = 9.6
WHONIX_COMPONENTS += Whonix

# whonix-setup-wizard
# -----------------------------------------------------------------------------
export GIT_URL_whonix_setup_wizard = https://github.com/Whonix/whonix-setup-wizard.git
export BRANCH_whonix_setup_wizard = 0.7-1
WHONIX_COMPONENTS += whonix-setup-wizard

# whonix-repository
# -----------------------------------------------------------------------------
export GIT_URL_whonix_repository = https://github.com/Whonix/whonix-repository.git
export BRANCH_whonix_repository = 1.1-1
WHONIX_COMPONENTS += whonix-repository

# python-guimessages
# -----------------------------------------------------------------------------
export GIT_URL_python_guimessages = https://github.com/Whonix/python-guimessages.git
export BRANCH_python_guimessages = 0.3-1
WHONIX_COMPONENTS += python-guimessages

ifndef INCLUDED
.PHONY: import-keys
import-keys: import-whonix-keys
	@true

.PHONY: get-sources
get-sources: import-keys
get-sources: GIT_REPOS := $(addprefix $(SRC_DIR)/,$(WHONIX_COMPONENTS))
get-sources:
	@set -a; \
	pushd $(BUILDER_DIR) &> /dev/null; \
	SCRIPT_DIR=$(BUILDER_DIR)/scripts; \
	SRC_ROOT=$(BUILDER_DIR)/$(SRC_DIR); \
	for REPO in $(GIT_REPOS); do \
		if [ ! -d $$REPO ]; then \
			$$SCRIPT_DIR/get-sources || exit 1; \
		fi; \
	done; \
	popd &> /dev/null

.PHONY: verify-sources
verify-sources:
	@true
endif

# vim: filetype=make
