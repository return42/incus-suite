# -*- sh-shell: bash -*--
# SPDX-License-Identifier: AGPL-3.0-or-later

# shellcheck disable=SC2034
LXC_SUITE_NAME="dev"

suite_install() {
    (
        set -e
        # make re-install and remove any previous installation
        suite_uninstall
        # ...
    )
    sh.prompt-err $?
}

suite_uninstall() {
    (
        set -e
        # ...
    )
    sh.prompt-err $?
}
