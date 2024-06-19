.DELETE_ON_ERROR:
.SHELLFLAGS := -eu -o pipefail -c

ifneq ($(QUIET),)
MAKEFLAGS += --no-print-directory --quiet
endif

SUBDIRS := const utils math mtx chem
BUILD_SUBDIR := @$(MAKE) -C
CHECK_SUBDIR := @$(MAKE) check -C

all: $(SUBDIRS)

include make/setup-builddir.mk
include make/subdir-deps.mk

clean:
	@rm -rf build
	@for subdir in $(SUBDIRS); do \
	  $(MAKE) --no-print-directory -C $$subdir clean; \
	done

.PHONY: $(SUBDIRS) clean
