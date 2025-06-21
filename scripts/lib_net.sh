# -*- mode: sh; sh-shell: bash -*-
# SPDX-License-Identifier: AGPL-3.0-or-later


# IP
# --

net.ip.globals() {
    # print list of host's SCOPE global addresses and adapters e.g::
    #
    #   $ net.ip.globals
    #   enp4s0|192.168.1.127
    #   lxdbr0|10.246.86.1
    #   lxdbr0|fd42:8c58:2cd:b73f::1

    ip -o addr show | sed -nr 's/[0-9]*:\s*([a-z0-9]*).*inet[6]?\s*([a-z0-9.:]*).*scope global.*/\1|\2/p'
}

net.ip.primary() {

    # print primary IP
    ip -o addr show \
        | sed -nr 's/[0-9]*:\s*([a-z0-9]*).*inet[6]?\s*([a-z0-9.:]*).*scope global.*/\2/p' \
        | head -n 1
}

net.fqdn() {
    local _ip
    _ip="${1:-$(net.ip.primary)}"
    dig -x "${_ip}" +short | sed 's/\.$//'
}
