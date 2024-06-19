FLAGS_CODE_SANITY := -Wno-unused-label -Wno-unused-variable -fstack-protector-all -fstack-clash-protection -D_FORTIFY_SOURCE=2
FFLAGS_FP_SANITY := -finit-real=snan -finit-derived -ffpe-trap=invalid,overflow,zero
FFLAGS_FORTRAN_SANITY := -std=f2008 -fimplicit-none -ffree-line-length-none -ffixed-line-length-none -Wno-unused-dummy-argument
FLAGS_REPRO := -ffp-contract=off
FLAGS_PREPROCESSOR := -cpp
FLAGS_OPT := -O2
FLAGS_DEBUG := -ggdb
# no-sign-zero only affects output formatting
FFLAGS_COMPAT := -fno-sign-zero
FFLAGS_FIXED := -ffixed-form -ffixed-line-length-none -x f77-cpp-input -std=f2008 -fstack-protector-all -fstack-clash-protection -D_FORTIFY_SOURCE=2
ifneq ($(and $(DEPENDS_ON),$(if $(NODEPS),,deps)),)
  FLAGS_DEPS := $(shell pkg-config --cflags $(DEPENDS_ON)) -Ipublic -Iprivate
endif

FFLAGS_LEGACY := $(FFLAGS_FP_SANITY) $(FLAGS_REPRO) $(FLAGS_OPT) $(FLAGS_PREPROCESSOR) $(FLAGS_DEBUG) $(FFLAGS_COMPAT) $(FLAGS_DEPS) $(FFLAGS_FIXED) $(FFLAGS)
FFLAGS := $(FLAGS_CODE_SANITY) $(FFLAGS_FP_SANITY) $(FFLAGS_FORTRAN_SANITY) $(FLAGS_REPRO) $(FLAGS_OPT) $(FLAGS_PREPROCESSOR) $(FLAGS_DEBUG) $(FFLAGS_COMPAT) $(FLAGS_DEPS) $(FFLAGS)
CFLAGS := $(FLAGS_CODE_SANITY) $(FLAGS_REPRO) $(FLAGS_OPT) $(FLAGS_PREPROCESSOR) $(FLAGS_DEBUG) $(FLAGS_DEPS) $(FLAGS_FIXED) $(CFLAGS)

PREPROCESS := gfortran -cpp -E
FCOMPILE := gfortran $(FFLAGS) -c
FCOMPILE_LEGACY := gfortran $(FFLAGS_LEGACY) -c
CCOMPILE := gcc $(CFLAGS) -c
ifneq ($(and $(DEPENDS_ON),$(if $(NODEPS),,deps)),)
  LIB_DEP_ARGS := $(shell pkg-config --libs --static $(DEPENDS_ON))
endif
LIB_TOOL_STATIC := ar rcs
LIB_TOOL_DYNAMIC := gfortran -dynamic
EXECUTABLE := gfortran
