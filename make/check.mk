CHECKER := $(BUILD_DIR)/bin/checker
CHECK_RESULT_DIR := $(BUILD_DIR)
CHECK_RESULTS := $(CHECK_RESULT_DIR)/check-results
CHECK_RESULTS_GOLDEN := test/test_output

$(CHECKER): $(ALL_DEPS) $(OBJS_CHECK) | $(BUILD_DIR)/bin/
	$(EXECUTABLE) -o $(CHECKER) $(OBJS_CHECK) $(shell PKG_CONFIG_PATH=$(BUILD_DIR)/lib/pkgconfig:$(PKG_CONFIG_PATH) pkg-config --libs --static mesa-$(MODULE_NAME))

ifneq ($(OBJS_CHECK),)
  $(CHECK_RESULTS) &: $(CHECKER) | $(CHECK_RESULT_DIR)/
	pushd test; ../$(CHECKER) > ../$(CHECK_RESULTS); popd
	diff -b $(CHECK_RESULTS) $(CHECK_RESULTS_GOLDEN)

  check: $(CHECK_RESULTS)
else
  check:
	$(error No test sources specified)
endif
