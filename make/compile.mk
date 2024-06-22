MODULE_SUBDIR := modules
MODULE_DIR := $(BUILD_DIR)/$(MODULE_SUBDIR)
SCRATCH_DIR := $(BUILD_DIR)/scratch

escape = '$(subst ','\'',$(1))'

define to_obj_ext
  $(patsubst %.f90,%.o, \
  $(patsubst %.F90,%.o, \
  $(patsubst %.f,%.o,	\
  $(patsubst %.c,%.o,	\
  $(addprefix $(BUILD_DIR)/, $(1) \
  )))))
endef

OBJS = $(call to_obj_ext,$(SRCS) $(SRCS_GENERATED))
ifneq ($(SRCS_CHECK),)
  OBJS_CHECK = $(call to_obj_ext,$(SRCS_CHECK) $(SRCS_CHECK_GENERATED))
endif
MODULES := $(addprefix $(MODULE_DIR)/, $(MODULES))

MAKEDEPF90 := makedepf90 -free -m $(MODULE_SUBDIR)/%m.mod -B $(BUILD_DIR)

ifeq ($(NODEPS),)
  FORTRAN_SOURCES := $(filter-out %.c, $(SRCS) $(SRCS_CHECK) $(addprefix $(BUILD_DIR)/,$(SRCS_GENERATED) $(SRCS_CHECK_GENERATED)))
  $(BUILD_DIR)/depend : $(FORTRAN_SOURCES) | $(BUILD_DIR)
	$(MAKEDEPF90) $(MAKEDEPF90FLAGS) -I public:private $(FORTRAN_SOURCES) | \
	INSTALL_INCLUDES=$(call escape,$(INSTALL_INCLUDES)) \
	MODULES=$(call escape,$(MODULES)) \
	BUILD_DIR=$(call escape,$(BUILD_DIR)) \
	$(MAKE_DIR)/gen-compile-tree > $(BUILD_DIR)/depend

  include $(BUILD_DIR)/depend
endif

$(BUILD_DIR)/%.o: %.c
	$(CCOMPILE) $< -o $@
