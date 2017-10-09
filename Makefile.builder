#!/usr/bin/make -f

## Copyright (C) 2012 - 2014 Patrick Schleizer <adrelanos@riseup.net>
## See the file COPYING for copying conditions.

# Environment variables (set in builder.conf) that should be made available to
# template build scripts
TEMPLATE_ENV_WHITELIST += WHONIX_APT_REPOSITORY_OPTS WHONIX_ENABLE_TOR \
    WHONIX_DIR WHONIX_TBB_VERSION
