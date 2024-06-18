# needs: MODULE_NAME, SRCS, PREFIX, MODULE_FILES

# Makefile sanity

MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

BUILD_DIR := build

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)%/:
	mkdir -p $@

NODEPS := $(filter clean,$(MAKECMDGOALS))

ifeq ($(MODULE_NAME),)
  $(error Missing module name)
endif

include compile-settings-gnu.mk
include compile.mk
include install-commands.mk

ifeq ($(BINTYPE), static-lib)
  include link-static.mk
else ifeq ($(BINTYPE), dynamic-lib)
  include link-dynamic.mk
else ifeq ($(BINTYPE), executable)
  include link-exec.mk
else
  $(error Unknown or unset BINTYPE)
endif

ALL_DEPS += $(OBJ_OUT) $(MODULES)

all: $(ALL_DEPS)

install: $(INSTALL_COMMANDS)

include check.mk

clean:
	@rm -rf $(BUILD_DIR)

.DEFAULT_GOAL := all
