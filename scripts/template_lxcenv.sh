# -*- mode: sh; sh-shell: bash -*-
# SPDX-License-Identifier: AGPL-3.0-or-later
# shellcheck disable=SC2269

#### HINT: this is a template file, all unquoted environment variables will be
####       replaced by real values!!
####
#### \${LXC_GUEST_MOUNT}            --> ${LXC_GUEST_MOUNT}
#### \${LXC_INCUS_SUITE_ROOT_GUEST} --> ${LXC_INCUS_SUITE_ROOT_GUEST}

# Location in the container where all folders from HOST are mounted
export LXC_GUEST_MOUNT="${LXC_GUEST_MOUNT}"
export LXC_INCUS_SUITE_ROOT="${LXC_INCUS_SUITE_ROOT_GUEST}"

# source minimal environment
# shellcheck source=./main.sh
. "${LXC_INCUS_SUITE_ROOT_GUEST}/scripts/lib_lxcenv.sh"
