# Build

MODULE_NAME := math
SRCS := public/math_def.f90 \
        private/math_io.f90 \
        private/math_pown.f90
SRCS_CHECK = test/src/test_math.f90
INTERNAL_DEPENDS_ON := const utils
EXTERNAL_DEPENDS_ON :=
BINTYPE := static-lib

ifneq ($(NOCRLIBM),)
SRCS += public/math_lib_intrinsic.f90
else
SRCS += public/math_lib_crmath.f90
EXTERNAL_DEPENDS_ON += crlibm-fortran
endif

# Testing

ifneq ($(NOCRLIBM),)
CHECK_RESULTS_GOLDEN := test/test_output.INTRINSIC
else
CHECK_RESULTS_GOLDEN := test/test_output.CRMATH
endif

# Install

MODULES := math_def.mod math_lib.mod
INSTALL_INCLUDES :=

include ../make/Makefile
