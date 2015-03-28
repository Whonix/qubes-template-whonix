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
	@if [ "$$WHONIX" == "1" ]; then \
	    export GNUPGHOME="$(SCRIPT_DIR)/keyrings/git"; \
            if ! gpg --list-keys 916B8D99C38EAF5E8ADC7A2A8D66066A2EEACCDA >/dev/null 2>&1; then \
                echo "**********************************************************"; \
                echo "*** You've selected Whonix build, this will import     ***"; \
                echo "*** Whonix code signing key to qubes-builder, globally ***"; \
                echo "**********************************************************"; \
                echo -n "Do you want to continue? (y/N) "; \
                read answer; \
                [ "$$answer" == "y" ] || exit 1; \
                echo '916B8D99C38EAF5E8ADC7A2A8D66066A2EEACCDA:6:' | gpg --import-ownertrust; \
                gpg --import $(SCRIPT_DIR)/$(SRC_DIR)/template-whonix/keys/whonix-developer-patrick.asc; \
                gpg --list-keys; \
            fi; \
	    touch "$$GNUPGHOME/pubring.gpg"; \
	fi

get-sources:
	@true

import-keys: import-whonix-keys
	@true

verify-sources: import-keys
	@true

