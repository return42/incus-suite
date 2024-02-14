# -*- mode: sh; sh-shell: bash -*-
# SPDX-License-Identifier: AGPL-3.0-or-later

# shellcheck source=./lib_tui.sh
. /dev/null

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

    [ -z "${1}" ] && msg.err "missing conatiner <name>" && return 42

    msg.info "create /.lxcenv in instance ${1}"

    local lxcenv_template
    lxcenv_template="$(dirname "${BASH_SOURCE[0]}")/.lxcenv.template"

    exec 3> >(incus exec "${1}" -- bash)
    echo "cat > /.lxcenv" >&3
    # shellcheck disable=SC2086
    eval "echo \"$(cat "${lxcenv_template}")\"" >&3
    exec 3>&-
}
