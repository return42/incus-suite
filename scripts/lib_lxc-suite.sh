# -*- mode: sh; sh-shell: bash -*-
# SPDX-License-Identifier: AGPL-3.0-or-later

# shellcheck source=./lib_tui.sh
. /dev/null

# shellcheck source=./lib_lxc-incus.sh
. /dev/null

sh.lib.import lxc-incus

# shellcheck source=./lib_lxc-incus.sh
. /dev/null

sh.lib.import lxcenv

_REQUIREMENTS=("${_REQUIREMENTS[@]}" column)

# Folder where the suites are located
LXC_SUITES_FOLDER="${LXC_SUITES_FOLDER:-${LXC_INCUS_SUITE_ROOT}/suites}"

lxc.suite.env.load() {

    # usage: lxc.suite.env.load <suite-name>
    #
    # Loads a named suite from folder ../suites/<suite-name>/suite.env

    msg.info "load environment of LXC suite: ${_BGreen}${1}${_creset}"

    if ! lxc.suite.env.load-file "${LXC_SUITES_FOLDER}/${1}/suite.env"; then
        msg.err "error while loading suite ${1}"
        return 42
    fi
}

lxc.suite.env.load-file() {

    # usage: lxc.suite.env.load-file <suite.env>
    #
    # Loads (sources) suite's environment from file <suite.env>.  The suite has
    # to define:
    #
    # - LXC_SUITE_NAME: shorthand name of the suite
    # - LXC_SUITE_INSTANCES: two dimensional array with remote and local image names
    # - LXC_SUITE_INIT: init script for the LXC instances
    #
    # see ../suites/lxc/suite.env for a good example.

    ! [ -f "${1}" ] && msg.err "file does not exists: ${1}" && return 42
    msg.debug "load suite's environment from: ${1}"
    source "${1}"
    local err=$?
    [ "${V:-0}" -ge 3 ] && lxc.suite.info | msg.prefix "${_BYellow}DEBUG:${_creset} " >&2
    sh.prompt-err "$err"
}

lxc.suite.env.missed() {
    # suite env needs to be loaded before suite command can be executed

    if [ -z "${LXC_SUITE_INSTANCES}" ]; then
        sh.die.caller 42 "suite env needs to be loaded first"
    else
        msg.debug "${LXC_SUITE_NAME} is active"
    fi
}

lxc.suite.info.help() {
    $FMT <<EOF
list images and more info of the suite

usage:
  ${MAIN} ${MAIN_CMD}
EOF
}
lxc.suite.info() {
    lxc.suite.env.missed

    local status
    echo -e "suite: ${LXC_SUITE_NAME}"
    echo -e "       ${LXC_SUITE_INIT}"
    (
        echo -e "instance image remote status IPv4 adapter PID snapshots base-image"
        for ((i = 0; i < ${#LXC_SUITE_INSTANCES[@]}; i += 2)); do
            readarray -t status < <(lxc.instance.get "${LXC_SUITE_NAME}-${LXC_SUITE_INSTANCES[i + 1]}" s4pSf)
            # status="${status:--}"
            echo -e "${LXC_SUITE_NAME}-${LXC_SUITE_INSTANCES[i + 1]}" \
                " ${LXC_SUITE_INSTANCES[i + 1]}" \
                " ${LXC_SUITE_INSTANCES[i]}" \
                " ${status[*]}"
        done
    ) | column -t
}

lxc.suite.build.help() {
    $FMT <<EOF
build instance from an image of the suite

usage:
  ${MAIN} ${MAIN_CMD} <image-name>

To build instances from all images of the suite use alias image-name 'all'.
EOF
}
lxc.suite.build() {
    lxc.suite.env.missed

    local image_name="${1}"
    [ -z "${image_name}" ] && msg.err "missing image <name>" && return 42

    if [ "${image_name}" = "all" ]; then
        for ((i = 0; i < ${#LXC_SUITE_INSTANCES[@]}; i += 2)); do
            lxc.suite._build "${LXC_SUITE_INSTANCES[i + 1]}"
        done
    else
        lxc.suite._build "${1}"
    fi
}

lxc.suite._build() {

    local image_name="${1}"
    local instance_name remote_name

    for ((i = 0; i < ${#LXC_SUITE_INSTANCES[@]}; i += 2)); do
        if [ "${LXC_SUITE_INSTANCES[i + 1]}" = "${image_name}" ]; then
            remote_name="${LXC_SUITE_INSTANCES[i]}"
            instance_name="${LXC_SUITE_NAME}-${LXC_SUITE_INSTANCES[i + 1]}"
            break
        fi
    done

    if [ -z "${instance_name}" ]; then
        lxc.suite.info
        sh.die.err 42 "image ${image_name} not exists in suite ${LXC_SUITE_NAME}"
    fi

    lxc.image.copy "${remote_name}" "${image_name}"
    lxc.instance.init "${image_name}" "${instance_name}"
    lxc.instance.configure "${instance_name}"
    lxc.suite.init "${image_name}" "${LXC_SUITE_INIT}"
}

lxc.suite.del.help() {
    $FMT <<EOF
delete instance of LXC suite

usage:
  ${MAIN} ${MAIN_CMD} <image-name>

To delete all instances from the LXC suite use alias image-name 'all'.
EOF
}
lxc.suite.del() {
    lxc.suite.env.missed

    local image_name="${1}"
    [ -z "${image_name}" ] && msg.err "missing image <name>" && return 42

    if [ "${image_name}" = "all" ]; then
        for ((i = 0; i < ${#LXC_SUITE_INSTANCES[@]}; i += 2)); do
            lxc.instance.del "${LXC_SUITE_NAME}-${LXC_SUITE_INSTANCES[i + 1]}"
            echo $?
        done
    else
        lxc.instance.del "${LXC_SUITE_NAME}-${image_name}"
    fi
}

lxc.suite.init() {
    # usage:  lxc.suite.init <image-name> <init-script>
    #
    # Initializes the LXC <image-name>, with the commands in the file
    # <init-script>.

    lxc.suite.env.missed

    local image_name="${1}"
    [ -z "${image_name}" ] && msg.err "missing image <name>" && return 42

    local init_script="${2}"
    [ -z "${init_script}" ] && msg.err "missing <init-script>" && return 42
    ! [ -f "${init_script}" ] && msg.err "init-script not exists: ${init_script}" && return 42

    (
        set -e
        lxc.instance.start "${LXC_SUITE_NAME}-${image_name}"
        lxc.lxcenv.write "${LXC_SUITE_NAME}-${image_name}"

        msg.info "[lxc.suite.init] execute init script ${init_script} in ${LXC_SUITE_NAME}-${image_name}"
        <"${init_script}" incus exec "${LXC_SUITE_NAME}-${image_name}" -- bash |&
            msg.prefix "[${_BBlue}${LXC_SUITE_NAME}-${image_name}${_creset}] "

        exit "${PIPESTATUS[0]}"
    )
    sh.prompt-err $?
}

lxc.suite.start.help() {
    $FMT <<EOF
start instance from LXC suite

usage:
  ${MAIN} ${MAIN_CMD} <image-name>

To start all instances from the LXC suite use alias image-name 'all'.
EOF
}
lxc.suite.start() {
    lxc.suite.env.missed

    local image_name="${1}"
    [ -z "${image_name}" ] && msg.err "missing image <name>" && return 42

    if [ "${image_name}" = "all" ]; then
        for ((i = 0; i < ${#LXC_SUITE_INSTANCES[@]}; i += 2)); do
            lxc.instance.start "${LXC_SUITE_NAME}-${LXC_SUITE_INSTANCES[i + 1]}"
        done
    else
        lxc.instance.start "${LXC_SUITE_NAME}-${image_name}"
    fi
}

lxc.suite.stop.help() {
    $FMT <<EOF
stop instance from LXC suite

usage:
  ${MAIN} ${MAIN_CMD} <image-name>

To stop all instances from the LXC suite use alias image-name 'all'.
EOF
}
lxc.suite.stop() {
    lxc.suite.env.missed

    local image_name="${1}"
    [ -z "${image_name}" ] && msg.err "missing image <name>" && return 42

    if [ "${image_name}" = "all" ]; then
        for ((i = 0; i < ${#LXC_SUITE_INSTANCES[@]}; i += 2)); do
            lxc.instance.stop "${LXC_SUITE_NAME}-${LXC_SUITE_INSTANCES[i + 1]}"
        done
    else
        lxc.instance.stop "${LXC_SUITE_NAME}-${image_name}"
    fi
}

lxc.suite.exec.help() {
    $FMT <<EOF
run command in LXC instance

usage:
  ${MAIN} ${MAIN_CMD} <image-name> <cmd> ...

To run command in all instances from LXC suite alias use alias image-name 'all'.
EOF
}
lxc.suite.exec() {
    lxc.suite.env.missed

    local host_cwd guest_cwd instance_name
    local image_name="${1}"
    shift

    host_cwd="$(pwd)"
    guest_cwd="${LXC_GUEST_MOUNT}/$(basename "${host_cwd}")"

    [ -z "${image_name}" ] && msg.err "missing image <name>" && return 42

    if [ "${image_name}" = "all" ]; then
        for ((i = 0; i < ${#LXC_SUITE_INSTANCES[@]}; i += 2)); do
            instance_name="${LXC_SUITE_NAME}-${LXC_SUITE_INSTANCES[i + 1]}"
            if ! lxc.instance.exists "${instance_name}" &>/dev/null; then
                msg.err "instance ${instance_name} does not exists"
                continue
            fi
            lxc.instance.mount "${instance_name}" "${host_cwd}"
            lxc.suite._exec --force-interactive "${guest_cwd}" "${instance_name}" "$@"
        done
    else
        instance_name="${LXC_SUITE_NAME}-${image_name}"
        if ! lxc.instance.exists "${instance_name}" &>/dev/null; then
            msg.err "instance ${instance_name} does not exists"
            return 42
        fi
        lxc.instance.mount "${instance_name}" "${host_cwd}"
        lxc.suite._exec --force-interactive "${guest_cwd}" "${LXC_SUITE_NAME}-${image_name}" "$*"
    fi
}

lxc.suite._exec() {

    local lxc_interactive="${1}"
    shift
    local cwd="${1}"
    shift
    local instance_name="${1}"
    shift
    local exit_val=0

    msg.info "[${_BBlue}${instance_name}${_creset}] ${_BGreen}export FORCE_TIMEOUT=${FORCE_TIMEOUT} LXC_SUITE_NAME=${LXC_SUITE_NAME}${_creset}"
    msg.info "[${_BBlue}${instance_name}${_creset}] ${_BGreen}${*}${_creset}"
    # incus exec "${instance_name}" "${lxc_interactive}" \
    #     --cwd "${guest_lxc_suites_folder}" \
    #     -- "$@"
    incus exec "${instance_name}" "${lxc_interactive}" \
        --env "FORCE_TIMEOUT=${FORCE_TIMEOUT}" \
        --env "LXC_SUITE_NAME=${LXC_SUITE_NAME}" \
        --cwd "${cwd}" \
        -- bash -c "$*"
    exit_val=$?

    if [[ $exit_val -ne 0 ]]; then
        msg.warn "[${_BBlue}${instance_name}${_creset}] exit code (${_BRed}${exit_val}${_creset}) from ${_BGreen}${*}${_creset}"
    else
        msg.info "[${_BBlue}${instance_name}${_creset}] exit code (${exit_val}) from ${_BGreen}${*}${_creset}"
    fi
    return ${exit_val}
}
