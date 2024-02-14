# -*- mode: sh; sh-shell: bash -*-
# SPDX-License-Identifier: AGPL-3.0-or-later

template.eval() {

    # usage:
    #    template.eval {template} [dest]

    local template="${1}"
    shift
    local dest="${1}"

    [ ! -f "${template}" ] && msg.err "template file not exists: ${template} " && return 42

    if [ -z "${dest}" ]; then
        eval "echo \"$(cat "${template}")\""
    else
        eval "echo \"$(cat "${template}")\"" >"${dest}"
    fi
}
