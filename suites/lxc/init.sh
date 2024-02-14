# -*- sh-shell: bash -*--
# SPDX-License-Identifier: AGPL-3.0-or-later

# This is the init script; it is called in the instance of a suite after the
# instance has been built (``incus-suite suite.build ..``), see also:
#
# lxc.suite.build:
#   build instance from an image of the suite
#
# lxc.suite.init:
#   Initializes the LXC <image-name>, with the commands in the file
#   <init-script>.

# shellcheck source=../scripts/lib_tui.sh
. /dev/null

# shellcheck source=/dev/null
source /.lxcenv
sh.lib.import dist
sh.lib.import msg

exe() {
    echo -e "${_BRed}\$ ${_Blue}${*}${_creset}"
    "$@"
}

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
        arch)
            # FIXME: while updating the packages, udevadm reports a lot of
            # errors in an unprivileged container.  To reproduce::
            #
            #  $ incus exec lxc-arch -- udevadm trigger
            #
            # https://github.com/systemd/systemd/issues/13652

            exe pacman --noprogressbar -Syu --noconfirm
            exe pacman --noprogressbar -S --noconfirm sudo inetutils "${DIST_DEV_PACKAGES[@]}"
            echo 'Set disable_coredump false' >>/etc/sudo.conf
            ;;
        fedora | centos)
            exe dnf update -y
            exe dnf install -y sudo hostname "${DIST_DEV_PACKAGES[@]}"
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
    msg.info "distribution '${DIST_NAME}': initial setup completed."
)
err="$?"
[ "${err}" -ne "0" ] && msg.err "initial setup failed. ($err)"
exit "${err}"
