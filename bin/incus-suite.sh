#!/usr/bin/env bash
# -*- mode: sh; sh-shell: bash -*-
# SPDX-License-Identifier: AGPL-3.0-or-later

PRJ_ROOT=$(realpath "${BASH_SOURCE[0]}")
PRJ_ROOT="$(dirname "${PRJ_ROOT}")/.."
PRJ_ROOT="$(cd "${PRJ_ROOT}" && pwd -P)"
# shellcheck source=../scripts/main.sh
source "${PRJ_ROOT}/scripts/main.sh"
main.source.config lxc-incus.env

sh.lib.import dist
sh.lib.import lxc-suite

MAIN_CMD_LIST=(
    "prepare"
    "image: image.list image.del"
    "instance: instance.init instance.del instance.mount instance.unmount"
    "suite: suite.info suite.build suite.del suite.exec suite.start suite.stop"
)

prepare.help() { lxc.base.install.help; }
prepare() { lxc.base.install; }

image.list.help() { lxc.image.list.local.help; }
image.list() { lxc.image.list.local "$@"; }
image.del.help() { lxc.image.del.local.help; }
image.del() { lxc.image.del.local "$@"; }

instance.init.help() { lxc.instance.init.help; }
instance.init() { lxc.instance.init "$@"; }
instance.del.help() { lxc.instance.del.help; }
instance.del() { lxc.instance.del "$@"; }
instance.mount.help() { lxc.instance.mount.help; }
instance.mount() { lxc.instance.mount "$@"; }
instance.unmount.help() { lxc.instance.unmount.help; }
instance.unmount() { lxc.instance.unmount "$@"; }

lxc.suite.env.load "${LXC_DEFAULT_SUITE}"

suite.info.help() { lxc.suite.info.help; }
suite.info() { lxc.suite.info "$@"; }
suite.build.help() { lxc.suite.build.help; }
suite.build() { lxc.suite.build "$@"; }
suite.del.help() { lxc.suite.del.help; }
suite.del() { lxc.suite.del "$@"; }
suite.exec.help() { lxc.suite.exec.help; }
suite.exec() { lxc.suite.exec "$@"; }
suite.start.help() { lxc.suite.start.help; }
suite.start() { lxc.suite.start "$@"; }
suite.stop.help() { lxc.suite.stop.help; }
suite.stop() { lxc.suite.stop "$@"; }

main "$@"
