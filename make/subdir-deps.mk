define pc
PKG_CONFIG_PATH=$(addprefix ../,$(addsuffix /build/lib/pkgconfig,$(1))):$(PKG_CONFIG_PATH)
endef

const:
	$(BUILD_SUBDIR) $@

utils: const
	$(BUILD_SUBDIR) $@ $(call test_fn,$^)
