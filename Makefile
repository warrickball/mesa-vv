SUBDIRS := const utils
BUILD_SUBDIR := @$(MAKE) -C

define test_fn
PKG_CONFIG_PATH=$(addprefix ../,$(addsuffix /build/lib/pkgconfig,$(1))):$(PKG_CONFIG_PATH)
endef

const:
	$(BUILD_SUBDIR) $@

clean:
	@for subdir in $(SUBDIRS); do \
	  $(MAKE) --no-print-directory -C $$subdir clean; \
	done

.PHONY: $(SUBDIRS) clean
