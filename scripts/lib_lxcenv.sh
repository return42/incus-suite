# -*- mode: sh; sh-shell: bash -*-
# SPDX-License-Identifier: AGPL-3.0-or-later

SH_LIB_PATH="$(dirname "${BASH_SOURCE[0]}")"

# shellcheck source=./lib_sh.sh
source "${SH_LIB_PATH}/lib_sh.sh"

# shellcheck source=./lib_template.sh
. /dev/null

sh.lib.import template

lxc.lxcenv() {

    # Tests whether the process is running in a container.
    #
    # usage:  lxc.lxcenv && echo "inside a instance"
    #         lxc.lxcenv || echo "not in a instance"
    #
    # LXC instances created with the lxc-suite have the file /.lxcenv in the
    # root folder.  If this file exists, it is assumed that the process is
    # executed in a container.
    #
    # If the file does not exist, it is assumed that the process is not running
    # in a container and exit code 42 is returned.

    if [ ! -f /.lxcenv ]; then
        return 42
    fi
}

lxc.lxcenv.write() {

    # usage: lxc.lxcenv.write <instance-name>

    # Create a /.lxcenv file in the root folder.  Call this once after the
    # instance is initial started and before installing any boilerplate stuff.

    [ -z "${1}" ] && msg.err "missing container <name>" && return 42

    msg.info "create /.lxcenv in instance ${1}"

    local template
    local tmp_file

    template="$(dirname "${BASH_SOURCE[0]}")/template_lxcenv.sh"
    tmp_file=$(mktemp -u)

    template.eval "${template}" "${tmp_file}"
    incus file push "${tmp_file}" "${1}/.lxcenv"
    rm -f "${tmp_file}"
}
