# -*- sh-shell: bash -*--
# SPDX-License-Identifier: AGPL-3.0-or-later

# shellcheck source=/dev/null
source /.lxcenv

V=3
# shellcheck source=../scripts/main.sh
set -x
echo "YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY"
source "${LXC_INCUS_SUITE_ROOT}/scripts/main.sh"
sleep 5

sh.lib.import tui
sh.lib.import dist

exe() {
    echo -e "${_BRed}\$ ${_Blue}XXXXXXXXXXXXXXXXXXXXXXXXXX ${*}${_creset}"
    "$@"
}
msg.err() { echo -e "${_BRed}ERROR:${_creset} $*" >&2; }

(
    set -e
    case $DIST_ID in
        ubuntu | debian)
            export DEBIAN_FRONTEND=noninteractive
            exe apt-get update -y
            exe apt-get upgrade -y
            exe apt-get install -y sudo "${DIST_DEV_PACKAGES[@]}"
            echo 'Set disable_coredump false' >>/etc/sudo.conf
            ;;
        void)
            exe xbps-install -Syu
            exe xbps-install --yes sudo "${DIST_DEV_PACKAGES[@]}"
            ;;
        *)
            msg.err "distribution '${DIST_NAME}' not implemented"
            exit 42
            ;;
    esac
    echo "initial setup completed."
)
err="$?"
[ "${err}" -ne "0" ] && msg.err "initial setup failed. ($err)"
exit "${err}"
