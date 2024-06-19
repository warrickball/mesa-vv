# needs: MODULE_NAME, SRCS, PREFIX, MODULE_FILES

# Makefile sanity
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

.DELETE_ON_ERROR:
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.PHONY: clean print-mesa-deps install all check

# Position independent

MAKE_DIR := $(dir $(lastword $(MAKEFILE_LIST)))
MAKEFLAGS += -I$(MAKE_DIR)

DEPENDS_ON := $(EXTERNAL_DEPENDS_ON)
ifneq ($(INTERNAL_DEPENDS_ON),)
  DEPENDS_ON += $(addprefix mesa-,$(INTERNAL_DEPENDS_ON))
  PKG_CONFIG_PATH := $(shell MAKE_DIR=$(MAKE_DIR) $(MAKE_DIR)/gen-pkgconfig-path $(INTERNAL_DEPENDS_ON))
  export PKG_CONFIG_PATH
endif
NODEPS := $(or $(filter clean,$(MAKECMDGOALS)),$(filter print-mesa-deps,$(MAKECMDGOALS)))

include setup-builddir.mk

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

ALL_DEPS += $(OBJ_OUT) $(MODULES) $(INSTALL_INCLUDES_BUILD)

all: $(ALL_DEPS)

install: $(INSTALL_COMMANDS)

include check.mk

clean:
	@rm -rf $(BUILD_DIR)

print-mesa-deps:
	@echo $(INTERNAL_DEPENDS_ON)
