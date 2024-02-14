# SPDX-License-Identifier: AGPL-3.0-or-later

# shellcheck source=./lib_tui.sh
. /dev/null

sh.lib.import lxc-suite

# _REQUIREMENTS=( "${_REQUIREMENTS[@]}" bash)

LXC_SUITES_FOLDER="$(dirname "${BASH_SOURCE[0]}")"
LXC_SUITES_FOLDER="$(cd "${LXC_SUITES_FOLDER}/../suites" && pwd -P)"

LXC_BASE_PACKAGES=(bash git)

LXC_HOST_USER="${SUDO_USER:-$USER}"
LXC_HOST_USER_ID=$(id -u "${LXC_HOST_USER}")
LXC_HOST_GROUP_ID=$(id -g "${LXC_HOST_USER}")

# Location in the container where all folders from HOST are mounted
LXC_GUEST_MOUNT="/share"


# lxc-incus.init() {
#     # FIXME: what, when we are in a LXC instance?
#     true
# }

lxc.base.install() {
    dist.pkg.install "${LXC_BASE_PACKAGES[@]}"
}

lxc.base.packages() {
    echo -e "\npackages::\n"
    # shellcheck disable=SC2068
    echo "  ${LXC_BASE_PACKAGES[*]}" | $FMT
}

lxc.image.copy.help() {
    $FMT <<EOF
copy a LXC image from a remote image server to the local server

usage:
  ${MAIN} ${MAIN_CMD} "<remote-name:image-name>" <local-name>
EOF
}

lxc.image.copy() {

    local remote_name="${1}"
    local local_name="${2}"

    [ -z "${remote_name}" ] && msg.err "missing remote <remote-name:image-name>" && return 42
    [ -z "${local_name}" ] && msg.err "missing <local-name>" && return 42

    if lxc.image.exists "local:${local_name}"; then
        msg.info "local image ${local_name} already exists"
    else
        msg.info "copy image to local image server // ${remote_name} --> ${local_name}"
	# incus shows progress on stdout / no msg.prefix here
	incus image copy "${remote_name}" local: --alias  "${local_name}"
    fi
}

lxc.image.exists() {

    # usage: lxc.image.exists <name> || echo "image <name> does exists"

    incus image info "$1" &>/dev/null
}

lxc.instance.init.help() {
    $FMT <<EOF
create LXC instance from a local image

usage:
  ${MAIN} ${MAIN_CMD} <image-name> <instance-name>
EOF
}

lxc.instance.init() {

    local image_name="$1"
    local instance_name="$2"

    [ -z "${image_name}" ] && msg.err "missing <image-name>" && return 42
    [ -z "${instance_name}" ] && msg.err "missing <instance-name>" && return 42

    if ! lxc.image.exists "local:${image_name}"; then
        msg.info "local image ${image_name} does not yet exists"
	return 42
    fi
    if lxc.instance.exists "${instance_name}" &>/dev/null; then
        msg.info "instance '${instance_name}' already exists"
    else
        msg.info "create instance instance: ${instance_name}"
        incus init "local:${image_name}" "${instance_name}"
    fi
}

lxc.instance.exists() {

    # usage: lxc.instance.exists <name> || echo "instance <name> does exists"

    [ -z "${1}" ] && msg.err "missing conatiner <name>" && return 42
    incus info "$1" &>/dev/null
}

lxc.instance.del.help() {
    $FMT <<EOF
delete LXC instance

usage:
  ${MAIN} ${MAIN_CMD} <instance-name>
EOF
}

lxc.instance.del() {

    local instance_name="$1"
    [ -z "${instance_name}" ] && msg.err "missing instance <name>" && return 42

    if lxc.instance.exists "${instance_name}" &>/dev/null; then
        msg.info "stop & delete instance ${_BBlue}${instance_name}${_creset}"
        incus stop --force "${instance_name}" &>/dev/null
        incus delete "${instance_name}"
    else
        msg.warn "instance '${instance_name}' does not exist / can't delete :o"
    fi
}

lxc.instance.start.help() {
    $FMT <<EOF
start LXC instance

usage:
  ${MAIN} ${MAIN_CMD} <instance-name> [<sec>]

Checks whether the instance is already running and starts it if necessary.
After the instance has been started, it waits <sec> (default 10) and then checks
whether the instance has an connection to the internet.
EOF
}

lxc.instance.start() {

    local instance_name="${1}"
    [ -z "${instance_name}" ] && msg.err "missing instance <name>" && return 42

    ! lxc.instance.exists "${instance_name}" \
	&& msg.err "unknown container: ${instance_name}" \
	&& return 42
    local wait_sec="${2:-10}"
    local status

    status="$(lxc.instance.get "${instance_name}" s)"
    if [ "${status}" == "RUNNING" ]; then
	msg.debug "[${_BBlue}${instance_name}${_creset}] already running .."
	return 0
    fi
    msg.info "[${_BBlue}${instance_name}${_creset}] start .."
    if incus start -q "${instance_name}" &>/dev/null; then
        sleep "${wait_sec}" # guest needs some time to come up and get an IP
    fi
    if ! lxc.instance.internet "${instance_name}"; then
        msg.err "LXC instance ${instance_name} has no internet connectivity!"
	return 42
    fi
}

lxc.instance.stop.help() {
    $FMT <<EOF
stop LXC instance

usage:
  ${MAIN} ${MAIN_CMD} <instance-name>
EOF
}
lxc.instance.stop() {

    local instance_name="$1"
    [ -z "${instance_name}" ] && msg.err "missing instance <name>" && return 42
    ! lxc.instance.exists "${instance_name}" && msg.err "unknown container: ${instance_name}" && return 42

    msg.info "[${_BBlue}${instance_name}${_creset}] stop .."
    incus stop "${instance_name}"
}

lxc.instance.internet.help() {
    $FMT <<EOF
check internet connectivity of the LXC instance

usage:
  ${MAIN} ${MAIN_CMD} <instance-name> [IP]

sends a ping from within the instancee to IP, if non IP is geiven the default IP
8.8.8.8 is used.
EOF
}

lxc.instance.get() {

    # usage: lxc.instance.get <instance-name> <properties>
    #
    # Returns properites of <instance-name>, about properties see::
    #
    #   incus list --help
    #
    # Example instance lxc-arch and list IPv4, IPv6, disk usage, Memory usage
    # (%), PID of the instance's init process, CPU usage (in seconds), Type
    # (CONTAINER or VIRTUAL-MACHINE) and state.
    #
    # lxc.instance.get lxc-arch 46DMputs

    local out
    local instance_name="$1"
    [ -z "${instance_name}" ] && msg.err "missing instance <name>" && return 42
    shift

    out="$(incus list name="${instance_name}"  -c "$*" -f csv 2>&1)"
    exit_code=$?
    if [ ${exit_code} -ne 0 ]; then
	sh.die.err 42 "lxc.instance.get: $out"
    fi
    if [ -z "${out}" ]; then
	msg.debug "lxc.instance.get: instance ${instance_name} is unknown"
	return 42
    fi
    IFS=',' read -ra ADDR <<< "${out}"
    for v in "${ADDR[@]}"; do
	echo "${v}"
    done
}


lxc.instance.internet() {

    local ret_val=0
    local instance_name="$1"
    [ -z "${instance_name}" ] && msg.err "missing instance <name>" && return 42
    local internet_ip="${2:-8.8.8.8}"

    # msg.info "check internet connectivity ..."
    if ! incus exec "${instance_name}" -- ping -c 1 "${internet_ip}" &>/dev/null; then
        ret_val=1
	msg.err "internet connectivity [${_BRed}FAILED${_creset}]"
        msg.info "Most often the connectivity is blocked by a docker installation:"
        msg.info "Whenever docker is started (reboot) it sets the iptables policy "
        msg.info "for the FORWARD chain to DROP, see:"
	# FIXME: move the doc from SearXNG to here in this project
        msg.info "    https://docs.searxng.org/utils/lxc.sh.html#internet-connectivity-docker"
        iptables-save | grep ":FORWARD"
    else
	msg.info "internet connectivity [${_BGreen}OK${_creset}]"
    fi
    return $ret_val
}

lxc.instance.configure() {

    local instance_name="$1"
    [ -z "${instance_name}" ] && msg.err "missing instance <name>" && return 42

    msg.info "[${_BBlue}${instance_name}{_creset}] configure instance ..."

    # https://linuxcontainers.org/incus/docs/main/userns-idmap/#custom-idmaps
    #
    msg.info "[${_BBlue}${instance_name}{_creset}] map uid/gid from host to container"
    echo -e -n "uid ${LXC_HOST_USER_ID} 0\\ngid ${LXC_HOST_GROUP_ID} 0"\
        | incus config set "${instance_name}" raw.idmap -
}

lxc.instance.share.help() {
    $FMT <<EOF
mount folder from HOST system within instance (only CONTAINER)

usage:
  ${MAIN} ${MAIN_CMD} <instance-name> <host-folder> [<basename>]

In the instance, the <host-folder> is then available at mount point:

  ${LXC_GUEST_MOUNT}/<basename>

If argument <basename> is not given, it is the base name of <host-folder>.

HINT: only CONTAINER instances / VIRTUAL-MACHINE instances are not supported!
EOF
}

lxc.instance.share() {

    local instance_name="$1"
    [ -z "${instance_name}" ] && msg.err "missing instance <name>" && return 42

    local host_folder="$2"
    [ -z "${host_folder}" ] && msg.err "missing <host-folder>" && return 42
    [ ! -d "${host_folder}" ] && msg.err "folder ${host_folder} does not exists" && return 42

    local guest_folder="${LXC_GUEST_MOUNT}/${3-$(basename "${host_folder}")}"

    msg.info "[${_BBlue}${instance_name}${_creset}] share ${host_folder} from HOST into GUEST ${guest_folder}"

    # https://linuxcontainers.org/incus/docs/main/reference/devices_disk/
    #
    # - source: Source of a file system or block device
    # - path: inside the instance where the disk will be mounted (only for containers)
    #
    # FIXME:  !!! only for containers !!!

    incus config device add "${instance_name}" "${guest_folder}_share" disk \
        source="${host_folder}" \
        path="${guest_folder}"
    [ "${V}" -ge 3 ] && incus config show "${instance_name}" && ui.press-key 10
}

lxc.lxcenv() {

    # Tests whether the process is running in a container.
    #
    # usage:  lxc.lxcenv && echo "inside a instance"
    #         lxc.lxcenv || echo "not in a instance"
    #
    # If exists, the file /.lxcenv in the root folder (of the instance) is
    # sourced.  This file is created by function lxc.lxcenv.write().
    #
    # If the file exists, it is assumed that we are in a instance (exit-code
    # 0).  If the file does not exist, it is assumed that we are not in a
    # instance and the function ends with an exit-code 42.
    #

    if [ ! -f /.lxcenv ]; then
	return 42
    fi

    source /.lxcenv

    # FIXME: when in a instance and the build folders are mountet from the HOST
    # system, the build folders needs to be in a sub-folder // when HOST's build
    # folder is /foo/bar/build the build folder of the guest should be
    # /foo/bar/<guest-hostname>/build

    # LXC_ENV_FOLDER=
    # if in_instance; then
    #     LXC_ENV_FOLDER="lxc-env/$(hostname)/"
    #
    #     PYDIST="${LXC_ENV_FOLDER}${PYDIST}"
    #     PYBUILD="${LXC_ENV_FOLDER}${PYBUILD}"
    #     DOCS_DIST="${LXC_ENV_FOLDER}${DOCS_DIST}"
    #     DOCS_BUILD="${LXC_ENV_FOLDER}${DOCS_BUILD}"
    # fi

}

lxc.lxcenv.write() {

    # usage: lxc.lxcenv.write <instance-name>

    # Create a /.lxcenv file in the root folder.  Call this once after the
    # instance is initial started and before installing any boilerplate stuff.

    [ -z "${1}" ] && msg.err "missing conatiner <name>" && return 42

    msg.info "create /.lxcenv in instance ${1}"

    cat <<EOF | incus exec "${1}" -- bash | msg.prefix "[${_BBlue}${1}${_creset}] "
touch "/.lxcenv"
ls -l "/.lxcenv"
EOF
}
