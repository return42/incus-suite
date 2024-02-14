# SPDX-License-Identifier: AGPL-3.0-or-later

# shellcheck source=./lib_tui.sh
. /dev/null

# shellcheck source=./lib_lxc-incus.sh
. /dev/null

_REQUIREMENTS=( "${_REQUIREMENTS[@]}" column)

lxc.suite.info.help() {
    $FMT <<EOF
list images and more info of the suite

  usage: ${MAIN} ${MAIN_CMD}
EOF
}
lxc.suite.info() {

    #  suite env needs to be loaded before, see lxc.suite.env.load()

    echo -e "suite: ${LXC_SUITE_NAME}"
    echo -e "       ${LXC_SUITE_INIT}"
    (
	echo -e "instance image remote"
	for ((i=0; i<${#LXC_SUITE_INSTANCES[@]}; i+=2)); do
	    echo -e "${LXC_SUITE_NAME}-${LXC_SUITE_INSTANCES[i+1]}"\
		 " ${LXC_SUITE_INSTANCES[i+1]}"\
		 " ${LXC_SUITE_INSTANCES[i]}"
	done
    ) | column -t
}

lxc.suite.build.help() {
    $FMT <<EOF
build instance from an image of the suite

  usage: ${MAIN} ${MAIN_CMD} <image-name>
EOF
}
lxc.suite.build() {

    #  suite env needs to be loaded before, see lxc.suite.env.load()

    local image_name="${1}"
    local instance_name remote_name

    [ -z "${image_name}" ] && msg.err "missing image <name>" && return 42

    for ((i=0; i<${#LXC_SUITE_INSTANCES[@]}; i+=2)); do
	if [ "${LXC_SUITE_INSTANCES[i+1]}" = "${image_name}" ]; then
	    remote_name="${LXC_SUITE_INSTANCES[i]}"
	    instance_name="${LXC_SUITE_NAME}-${LXC_SUITE_INSTANCES[i+1]}"
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
    lxc.suite.init "${instance_name}" "${LXC_SUITE_INIT}"
}


lxc.suite.init() {

    # usage:  lxc.suite.init <instance-name> <init-script>
    #
    # Initializes the LXC <instance-name>, with the commands in the file
    # <init-script>.

    local instance_name="${1}"
    [ -z "${instance_name}" ] && msg.err "missing instance <name>" && return 42
    local init_script="${2}"
    [ -z "${init_script}" ] && msg.err "missing <init-script>" && return 42
    ! [ -f "${init_script}" ] && msg.err "init-script not exists: ${init_script}" && return 42

    (	set -e
	lxc.instance.start "${instance_name}"
	lxc.lxcenv.write "${instance_name}"
	< "${init_script}" incus exec "${instance_name}" -- bash \
	    |& msg.prefix "[${_BBlue}${instance_name}${_creset}] "
	exit "${PIPESTATUS[0]}"
    )
    sh.prompt-err $?
}

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
    [ "${V}" -ge 3 ] && lxc.suite.info | msg.prefix "${_BYellow}DEBUG:${_creset} " >&2
    sh.prompt-err "$err"
}
