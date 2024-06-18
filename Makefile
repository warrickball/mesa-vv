.DELETE_ON_ERROR:
SUBDIRS := const utils math
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
