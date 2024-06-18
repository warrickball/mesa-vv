MODULE_SUBDIR := include
MODULE_DIR := $(BUILD_DIR)/$(MODULE_SUBDIR)

escape = '$(subst ','\'',$(1))'

define to_obj_ext
  $(patsubst %.f90,%.o, \
  $(patsubst %.F90,%.o, \
  $(patsubst %.f,%.o,	\
  $(patsubst %.c,%.o,	\
  $(addprefix $(BUILD_DIR)/, $(1) \
  )))))
endef

OBJS = $(call to_obj_ext,$(SRCS))
ifneq ($(SRCS_CHECK),)
  OBJS_CHECK = $(call to_obj_ext,$(SRCS_CHECK))
endif
MODULES := $(addprefix $(MODULE_DIR)/, $(MODULES))

MAKEDEPF90 := makedepf90 -free -m $(MODULE_SUBDIR)/%m.mod -B $(BUILD_DIR)

ifeq ($(NODEPS),)
  FORTRAN_SOURCES := $(filter-out %.c, $(SRCS) $(SRCS_CHECK))
  $(BUILD_DIR)/depend : $(FORTRAN_SOURCES) | $(BUILD_DIR)
	MAKEDEPF90=$(call escape,$(MAKEDEPF90)) \
	MAKEDEPF90FLAGS=$(call escape,$(MAKEDEPF90FLAGS)) \
	FORTRAN_SOURCES=$(call escape,$(FORTRAN_SOURCES)) \
	INSTALL_INCLUDES=$(call escape,$(INSTALL_INCLUDES)) \
	../make/gen-compile-tree > $(BUILD_DIR)/depend

  include $(BUILD_DIR)/depend
endif

$(BUILD_DIR)/%.o: %.c
	$(CCOMPILE) $< -o $@
