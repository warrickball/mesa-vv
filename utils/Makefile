# Build

MODULE_NAME := utils
SRCS := public/utils_def.f90 \
	public/utils_lib.f90 \
	private/utils_c_system.c \
	private/utils_dict.f90 \
	private/utils_idict.f90 \
	private/utils_nan_dp.f90 \
	private/utils_nan.f90 \
	private/utils_nan_qp.f90 \
	private/utils_nan_sp.f90 \
	private/utils_openmp_stub.f90 \
	private/utils_system.f90
SRCS_CHECK = test/src/test_utils.f90
INTERNAL_DEPENDS_ON := const
EXTERNAL_DEPENDS_ON :=

# Install

MODULES := utils_def.mod utils_lib.mod
INSTALL_INCLUDES := formats
BINTYPE := static-lib

MAKEFLAGS += -I../make

include ../make/Makefile
