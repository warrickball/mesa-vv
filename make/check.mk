CHECKER := $(BUILD_DIR)/bin/checker
CHECK_RESULT_DIR := $(BUILD_DIR)
CHECK_RESULTS := $(CHECK_RESULT_DIR)/check-results
CHECK_RESULTS_GOLDEN := test/test_output

$(CHECKER): $(ALL_DEPS) $(OBJS_CHECK) | $(BUILD_DIR)/bin/
	$(EXECUTABLE) -o $(CHECKER) $(OBJS_CHECK) $(LIB_DEP_ARGS) $(shell PKG_CONFIG_PATH=$(BUILD_DIR)/lib/pkgconfig pkg-config --libs --static mesa-$(MODULE_NAME))

ifneq ($(OBJS_CHECK),)
  check: $(CHECKER) | $(CHECK_RESULT_DIR)/
	$(CHECKER) > $(CHECK_RESULTS)
	diff -b $(CHECK_RESULTS) $(CHECK_RESULTS_GOLDEN)
else
  check:
	$(error No test sources specified)
endif
