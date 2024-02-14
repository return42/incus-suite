# -*- sh-shell: bash -*--
# SPDX-License-Identifier: AGPL-3.0-or-later

DIST_ID=$(source /etc/os-release; echo "$ID");
DIST_VERS=$(source /etc/os-release; echo "$VERSION_ID");

DIST_NAME="${DIST_ID}-${DIST_VERS}"
if [ -z "${DIST_VERS}" ]; then
    DIST_NAME="${DIST_ID}"
fi

if [ ! "${TERM}" = 'dumb' ] && [ ! "${TERM}" = 'unknown' ]; then
    _Blue='\e[0;94m'
    _BRed='\e[1;31m'
    _creset='\e[0m'
fi

exe() { echo -e "${_BRed}\$ ${_Blue}${*}${_creset}" ; "$@" ; }
msg.err() { echo -e "${_BRed}ERROR:${_creset} $*" >&2; }

(   set -e
    case $DIST_ID in
	ubuntu|debian)
	    export DEBIAN_FRONTEND=noninteractive
	    exe apt-get update -y
	    exe apt-get upgrade -y
	    exe apt-get install -y git curl wget
	    echo 'Set disable_coredump false' >> /etc/sudo.conf
	    ;;
	arch)
	    # FIXME: while updating the packages, udevadm reports a lot of
	    # errors in an unprivileged container.  To reproduce::
	    #
	    #  $ incus exec lxc-arch -- udevadm trigger
	    #
	    # https://github.com/systemd/systemd/issues/13652

	    exe pacman --noprogressbar -Syu --noconfirm
	    exe pacman --noprogressbar -S --noconfirm inetutils git curl wget sudo
	    echo 'Set disable_coredump false' >> /etc/sudo.conf
	    ;;
	fedora|centos)
	    exe dnf update -y
	    exe dnf install -y git curl wget hostname
	    echo 'Set disable_coredump false' >> /etc/sudo.conf
	    ;;
	void)
	    exe xbps-install --yes -S
	    exe xbps-install --yes -u
	    exe xbps-install --yes git curl wget
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
