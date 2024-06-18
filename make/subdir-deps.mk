define pc
PKG_CONFIG_PATH=$(addprefix ../,$(addsuffix /build/lib/pkgconfig,$(1))):$(PKG_CONFIG_PATH)
endef

define build_and_test
	$(BUILD_SUBDIR) $(1) $(call pc,$(2))
	$(CHECK_SUBDIR) $(1) $(call pc,$(2))
endef

const:
	$(call build_and_test,$@,$^)

utils: const
	$(call build_and_test,$@,$^)
