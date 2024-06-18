PKG_CONFIG := $(BUILD_DIR)/lib/pkgconfig/mesa-$(MODULE_NAME).pc
ALL_DEPS += $(PKG_CONFIG)
INSTALL_COMMANDS += install-pkgconfig

define PKG_CONFIG_CONTENTS
prefix=$${pcfiledir}/../..

Version: $(version)
Name: mesa-$(MODULE_NAME)
Requires.private: $(DEPENDS_ON)
Description: MESA $(MODULE_NAME) module
Cflags: -I$${prefix}/include
Libs: -L$${prefix}/lib -l$(MODULE_NAME)
endef

$(PKG_CONFIG): | $(BUILD_DIR)/lib/pkgconfig/
	$(file > $@,$(PKG_CONFIG_CONTENTS))
