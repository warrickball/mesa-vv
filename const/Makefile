# Build

MODULE_NAME := const
SRCS := public/const_def.f90 public/const_lib.f90
SRCS_CHECK := test/src/test_const.f
INTERNAL_DEPENDS_ON :=
EXTERNAL_DEPENDS_ON :=

# Install

MODULES := const_def.mod const_lib.mod
INSTALL_INCLUDES :=
BINTYPE := static-lib

MAKEFLAGS += -I../make

include ../make/Makefile
