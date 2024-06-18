OBJ_OUT := $(BUILD_DIR)/lib/lib$(MODULE_NAME).so
INSTALL_COMMANDS += install-lib

$(OBJ_OUT): $(OBJS) | $(BUILD_DIR)/lib/
	$(LIB_TOOL_DYNAMIC) -o $(OBJ_OUT) $(OBJS) $(LIB_DEP_ARGS)
  
include pkg-config.mk
