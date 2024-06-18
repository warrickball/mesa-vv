define pc
PKG_CONFIG_PATH=$(addprefix ../,$(addsuffix /build/lib/pkgconfig,$(1))):$(PKG_CONFIG_PATH)
endef

define build_and_test
$(BUILD_SUBDIR) $(1) $(call pc,$(2))
$(CHECK_SUBDIR) $(1) $(call pc,$(2))
endef

$(BUILD_DIR)/depend: $(addsuffix /Makefile,$(SUBDIRS)) make/gen-folder-deps | $(BUILD_DIR)/
	make/gen-folder-deps "$(MAKE)" $(SUBDIRS) > $(BUILD_DIR)/depend

include $(BUILD_DIR)/depend
