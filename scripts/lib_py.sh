# -*- mode: sh; sh-shell: bash -*-
# SPDX-License-Identifier: AGPL-3.0-or-later

_REQUIREMENTS=("${_REQUIREMENTS[@]}" python3)

# shellcheck source=./lib_dist.sh
. /dev/null
sh.lib.import dist

PY_OS_PYTHON=python
PY_OS_PIP=pip

case ${DIST_ID} in
    ubuntu | debian)
        PY_OS_PYTHON=python3
        PY_OS_PIP=pip3
        ;;
esac

# FIXME: How should this pathname (environment variable) be renamed if the
#        process executing it is running in a container (LXC / incus-suite)?
#
PY_VENV="${PRJ_ROOT-.}/.venv"

py.help() {
    cat <<EOF
py.:
  clean     : clean up python environment and remnants
  env.:
    activate: python virtual environment
    build   : build python virtual environment ($PY_VENV)
    drop    : remove $PY_VENV
EOF
}

py.clean() {
    msg.build CLEAN "clean up python environment and remnants"
    (
        set -e
        py.env.drop
        rm -rf ./.tox ./*.egg-info
        find . -name '*.pyc' -exec rm -f {} +
        find . -name '*.pyo' -exec rm -f {} +
        find . -name __pycache__ -exec rm -rf {} +
    )
}

py.env.activate() {
    # shellcheck source=/dev/null
    . "${PY_VENV}/bin/activate"
}

py.env.build() {
    msg.build ENV "build ${PY_VENV}"
    msg.debug "[py.env.build] PY_OS_PYTHON=${PY_OS_PYTHON}"
    msg.debug "[py.env.build] PY_OS_PIP=${PY_OS_PIP}"
    # https://docs.python.org/3/library/venv.html
    "${PY_OS_PYTHON}" -m venv "$PY_VENV"
    "${PY_VENV}/bin/python" -m pip install --upgrade pip
}

py.env.drop() {
    msg.build CLEAN "remove ${PY_VENV}"
    rm -rf "${PY_VENV}"
}
