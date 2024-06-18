SUBDIRS := const utils
BUILD_SUBDIR := @$(MAKE) -C
CHECK_SUBDIR := @$(MAKE) check -C

include make/subdir-deps.mk

clean:
	@for subdir in $(SUBDIRS); do \
	  $(MAKE) --no-print-directory -C $$subdir clean; \
	done

.PHONY: $(SUBDIRS) clean
