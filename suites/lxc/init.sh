# -*- sh-shell: bash -*--
# SPDX-License-Identifier: AGPL-3.0-or-later

# shellcheck disable=SC1091
echo "XXXXX -----------------------"
cat /.lxcenv  # erster lese zugriff .. datei existiert, ist aber leer
echo "XXXXX return code, erster lese zugriff: $?"
echo "XXXXX -----------------------"
cat /.lxcenv  # zweiter lese zugriff .. datei existiert und kann gelesen werden
echo "XXXXX return code, zweiter lese zugriff: $?"
echo "XXXXX -----------------------"
exit

source /.lxcenv

# shellcheck source=../../scripts/main.sh
source "${LXC_ROOT_FOLDER}/scripts/main.sh"
sh.lib.import dist


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
	    exe apt-get install -y sudo "${DIST_DEV_PACKAGES[@]}"
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
	    exe pacman --noprogressbar -S --noconfirm sudo inetutils "${DIST_DEV_PACKAGES[@]}"
	    echo 'Set disable_coredump false' >> /etc/sudo.conf
	    ;;
	fedora|centos)
	    exe dnf update -y
	    exe dnf install -y sudo hostname "${DIST_DEV_PACKAGES[@]}"
	    echo 'Set disable_coredump false' >> /etc/sudo.conf
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
