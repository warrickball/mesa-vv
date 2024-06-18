define build_and_test
$(BUILD_SUBDIR) $(1)
$(CHECK_SUBDIR) $(1)
endef

NODEPS := $(filter clean,$(MAKECMDGOALS))

ifeq ($(NODEPS),)
$(BUILD_DIR)/depend: $(addsuffix /Makefile,$(SUBDIRS)) make/gen-folder-deps | $(BUILD_DIR)
	make/gen-folder-deps "$(MAKE)" $(SUBDIRS) > $(BUILD_DIR)/depend
include $(BUILD_DIR)/depend
endif
