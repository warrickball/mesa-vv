# Build

MODULE_NAME := math
SRCS := public/math_def.f90 \
        private/math_io.f90 \
        private/math_pown.f90
SRCS_CHECK = test/src/test_math.f90
INTERNAL_DEPENDS_ON := const utils
EXTERNAL_DEPENDS_ON :=

ifneq ($(NOCRLIBM),)
SRCS += public/math_lib_intrinsic.f90
CHECK_RESULTS_GOLDEN := test/test_output.INTRINSIC
else
SRCS += public/math_lib_crmath.f90
EXTERNAL_DEPENDS_ON += crlibm-fortran
CHECK_RESULTS_GOLDEN := test/test_output.CRMATH
endif

# Install

MODULES := math_def.mod math_lib.mod
INSTALL_INCLUDES :=
BINTYPE := static-lib

include ../make/Makefile
