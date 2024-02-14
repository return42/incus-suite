# SPDX-License-Identifier: AGPL-3.0-or-later

DIST_ID=$(source /etc/os-release; echo "${ID}");
DIST_VERS=$(source /etc/os-release; echo "${VERSION_ID}");

dist.init() {

    # ubuntu, debian, arch, fedora, centos ...
    dist.pkg.defs
}

dist.pkg.defs() {

    # set package definitions

    case ${DIST_ID} in
	ubuntu|debian)
	    # apt packages
	    DIST_DEV_PACKAGES=(bash git jq build-essential) ;;
	arch)
            # pacman packages
            DIST_DEV_PACKAGES=(bash git jq base-devel) ;;
	fedora|centos)
	    # dnf packages / yum is old, buggy and not supported here in lib_dist.sh !!!
            DIST_DEV_PACKAGES=(bash git jq @development-tools) ;;
	*)
	    sh.die.err 42 "lib_dist.sh - ${DIST_ID}-${DIST_VERS} not yet implemented" ;;
    esac
}

# shellcheck disable=SC2034
DIST_DEV_PACKAGES=()


# distro's package manager
# ------------------------

_dist_pkg_info_is_updated=0

dist.pkg.install() {

    # usage: TITLE='install packages foo and bar' dist.pkg.install foo bar

    msg.title "${TITLE:-installation of packages}" section
    echo -e "\npackage(s)::\n"
    # shellcheck disable=SC2068
    echo "  $*" | ${FMT}

    if ! ui.yes-no "Should packages be installed?" Yn 30; then
        return 42
    fi
    case ${DIST_ID} in
        ubuntu|debian)
            if [[ ${_dist_pkg_info_is_updated} == 0 ]]; then
                export __dist_pkg_info_is_updated=1
                apt update
            fi
            apt-get install -m -y "$@"
            ;;
        arch)
            pacman --noprogressbar -Sy --noconfirm --needed "$@"
            ;;
	fedora|centos)
            dnf install -y "$@"
            ;;
    esac
}

dist.pkg.remove() {

    # usage: TITLE='uninstall packages foo and bar' dist.pkg.remove foo bar

    msg.title "${TITLE:-remove packages}" section
    echo -e "\npackage(s)::\n"
    # shellcheck disable=SC2068
    echo "  $*" | ${FMT}

    if ! ui.yes-no "Should packages be removed (purge)?" Yn 30; then
        return 42
    fi
    case ${DIST_ID} in
        ubuntu|debian)
            apt-get purge --autoremove --ignore-missing -y "$@"
            ;;
        arch)
            pacman --noprogressbar -R --noconfirm "$@"
            ;;
	fedora|centos)
            dnf remove -y "$@"
            ;;
    esac
}

dist.pkg.is-installed() {

    # usage: dist.pkg.is-installedl foopkg || dist.pkg.install foopkg

    case ${DIST_ID} in
        ubuntu|debian)
            dpkg -l "$1" &> /dev/null
            return $?
            ;;
        arch)
            pacman -Qsq "$1" &> /dev/null
            return $?
            ;;
	fedora|centos)
            dnf list -q --installed "$1" &> /dev/null
            return $?
            ;;
    esac
}
