OBJ_OUT := $(BUILD_DIR)/lib/lib$(MODULE_NAME).a
INSTALL_COMMANDS += install-lib

$(OBJ_OUT): $(OBJS) | $(BUILD_DIR)/lib/
	$(LIB_TOOL_STATIC) -o $(OBJ_OUT) $(OBJS)

include pkg-config.mk
