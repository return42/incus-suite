# -*- mode: sh; sh-shell: bash -*-
# SPDX-License-Identifier: AGPL-3.0-or-later

# shellcheck source=./lib_tui.sh
. /dev/null

_REQUIREMENTS=("${_REQUIREMENTS[@]}" readarray)

LXC_BASE_PACKAGES=(bash git)

# Location in the container where all folders from HOST are mounted
LXC_GUEST_MOUNT="/host-share"

# Folder of this incus-suite repo on HOST system
LXC_INCUS_SUITE_ROOT="${LXC_INCUS_SUITE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
# Folder of this incus-suite repo on GUEST system
LXC_INCUS_SUITE_ROOT_GUEST="${LXC_GUEST_MOUNT}/$(basename "${LXC_INCUS_SUITE_ROOT}")"

LXC_HOST_USER="${SUDO_USER:-$USER}"
LXC_HOST_USER_ID=$(id -u "${LXC_HOST_USER}")
LXC_HOST_GROUP_ID=$(id -g "${LXC_HOST_USER}")

# lxc-incus.init() {
#     # FIXME: what, when we are in a LXC instance?
#     true
# }

lxc.base.install.help() {
    $FMT <<EOF
install tools required by ${MAIN} (sudo)

usage:
  ${MAIN} ${MAIN_CMD}

To install packages from ${DIST_ID}'s package manager, super user privileges are
needed (sudo/su).
EOF
    lxc.base.packages
}

lxc.base.install() {
    TITLE="Installation of the tools required by lxc-incus" dist.pkg.install "${LXC_BASE_PACKAGES[@]}"
}

lxc.base.packages() {
    dist.pkg.show "${LXC_BASE_PACKAGES[@]}"
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
        incus image copy "${remote_name}" local: --alias "${local_name}"
    fi
}

lxc.image.list.local.help() {
    $FMT <<EOF
List local LXC images / incus image list local:

usage:
  ${MAIN} ${MAIN_CMD} ...
EOF
}

lxc.image.list.local() {

    incus image list "local:$1"
}

lxc.image.del.local.help() {
    $FMT <<EOF
Delete local LXC images / incus image delete local:

usage:
  ${MAIN} ${MAIN_CMD} [<local-name>]
EOF

}

lxc.image.del.local() {

    local line f l

    incus image list "local:$1"
    for line in $(incus image list "local:$1" --format csv --columns f,l); do
        IFS=, read -r f l <<<"$line"
        if ui.yes-no "Do you want to delete image $f ($l)?" Ny 10; then
            msg.info "delete image $f ($l)"
            incus image delete "$f" -v
        fi
    done
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

    [ -z "${1}" ] && msg.err "missing container <name>" && return 42
    incus info "$1" &>/dev/null
}

lxc.instance.del.help() {
    $FMT <<EOF
delete LXC instance

usage:
  ${MAIN} ${MAIN_CMD} [<instance-name>]
EOF
}

lxc.instance.del() {

    local instance_name="$1"

    if [ -z "${instance_name}" ]; then
        incus list --columns n,p,d,s,c,4,6
        for line in $(incus list --format csv --columns n); do
            IFS=, read -r instance_name <<<"$line"
            if ui.yes-no "Do you want to delete instance ${_BBlue}${instance_name}${_creset}?" Ny 10; then
                msg.info "stop & delete instance ${_BBlue}${instance_name}${_creset}"
                incus stop --force "${instance_name}" &>/dev/null
                incus delete "${instance_name}" -v
            fi
        done

    elif lxc.instance.exists "${instance_name}" &>/dev/null; then
        msg.info "stop & delete instance ${_BBlue}${instance_name}${_creset}"
        incus stop --force "${instance_name}" &>/dev/null
        incus delete "${instance_name}" -v
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

    ! lxc.instance.exists "${instance_name}" &&
        msg.err "unknown container: ${instance_name}" &&
        return 42
    local wait_sec="${2:-10}"
    local status

    status="$(lxc.instance.get "${instance_name}" s)"
    if [ "${status}" == "RUNNING" ]; then
        msg.info "[${_BBlue}${instance_name}${_creset}] already running .."
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
    ! lxc.instance.exists "${instance_name}" &&
        msg.err "unknown container: ${instance_name}" &&
        return 42

    local status
    status="$(lxc.instance.get "${instance_name}" s)"

    if [ "${status}" != "RUNNING" ]; then
        msg.info "[${_BBlue}${instance_name}${_creset}] not running (${status}).."
        return 0
    fi
    msg.info "[${_BBlue}${instance_name}${_creset}] stop .."
    incus stop "${instance_name}" --force
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

    out="$(incus list name="${instance_name}" -c "$*" -f csv 2>&1)"
    exit_code=$?
    if [ ${exit_code} -ne 0 ]; then
        sh.die.err 42 "lxc.instance.get: $out"
    fi
    if [ -z "${out}" ]; then
        msg.debug "lxc.instance.get: instance ${instance_name} is unknown"
        return 42
    fi
    IFS=',' read -ra ADDR <<<"${out}"
    for v in "${ADDR[@]}"; do
        echo "${v}"
    done
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

lxc.instance.internet() {

    local ret_val=0
    local instance_name="$1"
    [ -z "${instance_name}" ] && msg.err "missing instance <name>" && return 42
    local internet_ip="${2:-8.8.8.8}"

    # msg.info "check internet connectivity ..."
    if ! incus exec "${instance_name}" -- ping -c 1 "${internet_ip}" &>/dev/null; then
        ret_val=1
        # FIXME: needs more work ..
        msg.err "[${_BBlue}${instance_name}${_creset}] internet connectivity [${_BRed}FAILED${_creset}]"
        msg.info "Most often the connectivity is blocked by a docker installation:"
        msg.info "Whenever docker is started (on reboot) it sets the iptables policy "
        msg.info "for the FORWARD chain to DROP, see:"
        # FIXME: move the doc from SearXNG to here in this project
        msg.info "    https://docs.searxng.org/utils/lxc.sh.html#internet-connectivity-docker"
        # iptables-save | grep ":FORWARD"
    else
        msg.info "[${_BBlue}${instance_name}${_creset}] internet connectivity [${_BGreen}OK${_creset}]"
    fi
    return $ret_val
}

lxc.instance.configure() {

    local instance_name="$1"
    [ -z "${instance_name}" ] && msg.err "missing instance <name>" && return 42

    msg.info "[${_BBlue}${instance_name}${_creset}] configure instance ..."

    # https://linuxcontainers.org/incus/docs/main/userns-idmap/#custom-idmaps
    #
    msg.info "[${_BBlue}${instance_name}${_creset}] map uid/gid from host to container"
    echo -e -n "uid ${LXC_HOST_USER_ID} 0\\ngid ${LXC_HOST_GROUP_ID} 0" |
        incus config set "${instance_name}" raw.idmap -

    lxc.instance.mount "${instance_name}" "${LXC_INCUS_SUITE_ROOT}" "$(basename "${LXC_INCUS_SUITE_ROOT_GUEST}")"
}

lxc.instance.mount.help() {
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

lxc.instance.mount() {

    local instance_name="$1"
    [ -z "${instance_name}" ] && msg.err "missing instance <name>" && return 42

    local host_folder
    host_folder="$(cd "${2}" && pwd -P)"
    [ -z "${host_folder}" ] && msg.err "missing <host-folder>" && return 42
    [ ! -d "${host_folder}" ] && msg.err "folder ${host_folder} does not exists" && return 42

    local guest_folder="${LXC_GUEST_MOUNT}/${3-$(basename "${host_folder}")}"

    msg.info "[${_BBlue}${instance_name}${_creset}] mount ${host_folder} from HOST into GUEST ${guest_folder}"

    # https://linuxcontainers.org/incus/docs/main/reference/devices_disk/
    #
    # - source: Source of a file system or block device
    # - path: inside the instance where the disk will be mounted (only for containers)
    #
    # FIXME:  !!! only for containers !!!

    local source
    if incus config device get "${instance_name}" "${guest_folder}" source &>/dev/null; then
        source="$(incus config device get "${instance_name}" "${guest_folder}" source)"
        if [[ ${host_folder} -ef ${source} ]]; then
            msg.info "device ${guest_folder} already exists"
        else
            msg.err "device ${guest_folder} already exists but points to ${source}"
            return 42
        fi
    else
        incus config device add "${instance_name}" "${guest_folder}" disk \
            source="${host_folder}" \
            path="${guest_folder}"
    fi
    if [ "${V:-0}" -ge 3 ]; then
        incus config show "${instance_name}"
        ui.press-key 10
    fi
}

lxc.instance.unmount.help() {
    $FMT <<EOF
unmount folder from HOST system within instance (only CONTAINER)

usage:
  ${MAIN} ${MAIN_CMD} <instance-name> <host-folder>

HINT: only CONTAINER instances / VIRTUAL-MACHINE instances are not supported!
EOF
}

lxc.instance.unmount() {

    local instance_name="$1"
    [ -z "${instance_name}" ] && msg.err "missing instance <name>" && return 42

    local host_folder
    host_folder="$(cd "${2}" && pwd -P)"
    [ -z "${host_folder}" ] && msg.err "missing <host-folder>" && return 42
    [ ! -d "${host_folder}" ] && msg.err "folder ${host_folder} does not exists" && return 42

    local guest_folder="${LXC_GUEST_MOUNT}/${3-$(basename "${host_folder}")}"

    msg.info "[${_BBlue}${instance_name}${_creset}] unmount ${host_folder} from HOST within GUEST ${guest_folder}"

    # https://linuxcontainers.org/incus/docs/main/reference/devices_disk/
    #
    # - source: Source of a file system or block device
    # - path: inside the instance where the disk will be mounted (only for containers)
    #
    # FIXME:  !!! only for containers !!!

    local source
    if incus config device get "${instance_name}" "${guest_folder}" source &>/dev/null; then
        source="$(incus config device get "${instance_name}" "${guest_folder}" source)"
        if [[ ${host_folder} -ef ${source} ]]; then
            msg.info "unmount device ${guest_folder}"
            incus config device remove "${instance_name}" "${guest_folder}"
        else
            msg.err "device ${guest_folder} already exists but points to ${source}"
            return 42
        fi
    else
        msg.err "device ${guest_folder} does not exists"
    fi
    if [ "${V:-0}" -ge 3 ]; then
        incus config show "${instance_name}"
        ui.press-key 10
    fi
}
