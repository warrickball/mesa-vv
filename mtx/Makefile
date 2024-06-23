# Build

MODULE_NAME := mtx
LAPACK_QUAD_SRCS := \
   lapack_quad/qgttrf.f \
   lapack_quad/qgttrs.f \
   lapack_quad/qgtts2.f \
   lapack_quad/qgetrf.f \
   lapack_quad/qgetrs.f \
   lapack_quad/qgemv.f \
   lapack_quad/qgemm.f \
   lapack_quad/qgetf2.f \
   lapack_quad/qswap.f \
   lapack_quad/iqamax.f \
   lapack_quad/qtrsm.f \
   lapack_quad/qtrsv.f \
   lapack_quad/qger.f \
   lapack_quad/qscal.f \
   lapack_quad/qlamch.f \
   lapack_quad/qlaswp.f
SRCS := public/mtx_def.f \
        public/mtx_lib.f90 \
        private/DGBSVX_wrapper.f90 \
        private/bcyclic.f90 \
        private/mtx_support.f90 \
        private/pre_conditioners.f90 \
	$(LAPACK_QUAD_SRCS)
SRCS_GENERATED := private/my_lapack95_dble.f90 \
                  private/my_lapack95_quad.f90
SRCS_CHECK := test/src/test_banded.f90 \
              test/src/test_mtx.f90 \
              test/src/test_mtx_support.f90 \
              test/src/test_square.f90 \
              test/src/test_square_quad.f90
SRCS_CHECK_GENERATED := \
	test/src/test_block_tridiagonal_dble.f90 \
	test/src/test_block_tridiagonal_quad.f90
# TODO: Also contains test dependencies sadly, I should fix this at some point
INTERNAL_DEPENDS_ON := const utils math
EXTERNAL_DEPENDS_ON := lapack
BINTYPE := static-lib

# Testing

CHECK_RESULTS_GOLDEN := test/test_output

# Install

MODULES := mtx_def.mod mtx_lib.mod
INSTALL_INCLUDES := public/mtx_bcyclic_dble_decsol.dek \
                    public/mtx_dble_decsol.dek \
                    public/mtx_debug_decsol.dek \
                    public/mtx_decsol.dek \
                    public/mtx_decsolblk.dek \
                    public/mtx_decsolblk_dble.dek \
                    public/mtx_decsolblk_quad.dek \
                    public/mtx_decsolc.dek \
                    public/mtx_decsolcs.dek \
                    public/mtx_decsols.dek \
                    public/mtx_jac.dek \
                    public/mtx_lapack95.dek \
                    public/mtx_null_decsol.dek \
                    public/mtx_rcond.dek \
                    public/mtx_solve_routines_quad.inc \
                    public/mtx_tridiag_decsol.dek \
                    public/mtx_solve_routines.inc

include ../make/Makefile

# Custom build steps

$(BUILD_DIR)/private/my_lapack95_dble.f90: private/my_lapack95.F90 | $(BUILD_DIR)/private/
	$(PREPROCESS) -DDBLE $^ > $@

$(BUILD_DIR)/private/my_lapack95_quad.f90: private/my_lapack95.F90 | $(BUILD_DIR)/private/
	$(PREPROCESS) $^ > $@

$(BUILD_DIR)/test/src/test_block_tridiagonal_dble.f90: test/src/test_block_tridiagonal.f90 | $(BUILD_DIR)/test/src/
	$(PREPROCESS) -DDBLE $^ > $@

$(BUILD_DIR)/test/src/test_block_tridiagonal_quad.f90: test/src/test_block_tridiagonal.f90 | $(BUILD_DIR)/test/src/
	$(PREPROCESS) $^ > $@
