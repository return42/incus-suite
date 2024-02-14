# SPDX-License-Identifier: AGPL-3.0-or-later

include utils/makefile.include

# wrap ./prj script
# -----------------

PRJ += help env.build fmt.shell
PHONY += $(PRJ)
$(PRJ):
	$(Q)./prj $@

fmt: fmt.shell

# local TOPTARGETS
test::
	$(Q)grep -n FIXME ./scripts/* ./bin/* ./etc/* ./suites/*/* || true
	$(Q)shellcheck -x -s bash ./prj
	$(Q)./prj test.all

clean::
	$(Q)./prj $@
	$(Q)find . \( \
		-name '*.orig' -o -name '*.rej' -o -name '*~' -o -name '*.bak' \
	\) -exec rm -f {} +


# run make in subdirectories
# --------------------------

# Makefiles in subdirs needs to define TOPTARGETS::
#    .PHONY: all clean test build

TOPTARGETS := all clean test build

include utils/makefile.toptargets
