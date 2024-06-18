MODULE_SUBDIR := include
MODULE_DIR := $(BUILD_DIR)/$(MODULE_SUBDIR)

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
	$(MAKEDEPF90) $(MAKEDEPF90FLAGS) -I public:private $(FORTRAN_SOURCES) | sed -rn "s/([^ ]*) (.*): ([^ ]*) (.*)/echo \"\1 \2\&: \3 \4| \\\\\$$(MODULE_DIR)\/ \$$(dirname \1)\/ \n\t\\\\\$$(FCOMPILE) \3 -o \1 -J \\\\\$$(MODULE_DIR)\"/ep" | sed -r 's/\$$\(FCOMPILE\) ([^.]*).f /$$(FCOMPILE_LEGACY) \1.f /' > $(BUILD_DIR)/depend

  include $(BUILD_DIR)/depend
endif

$(BUILD_DIR)/%.o: %.c
	$(CCOMPILE) $< -o $@
