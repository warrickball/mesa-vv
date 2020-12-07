! ***********************************************************************
!
!   Copyright (C) 2010-2019  Bill Paxton & The MESA Team
!
!   MESA is free software; you can use it and/or modify
!   it under the combined terms and restrictions of the MESA MANIFESTO
!   and the GNU General Library Public License as published
!   by the Free Software Foundation; either version 2 of the License,
!   or (at your option) any later version.
!
!   You should have received a copy of the MESA MANIFESTO along with
!   this software; if not, it is available at the mesa website:
!   http://mesa.sourceforge.net/
!
!   MESA is distributed in the hope that it will be useful,
!   but WITHOUT ANY WARRANTY; without even the implied warranty of
!   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
!   See the GNU Library General Public License for more details.
!
!   You should have received a copy of the GNU Library General Public License
!   along with this software; if not, write to the Free Software
!   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
!
! ***********************************************************************


      module mlt_info

      use star_private_def
      use const_def
      use num_lib
      use utils_lib
      use mlt_get_results, only: Get_results

      implicit none

      private
      public :: set_mlt_vars, do1_mlt, do1_mlt_eval, set_grads, &
         set_gradT_excess_alpha, adjust_gradT_fraction, adjust_gradT_excess, &
         switch_to_no_mixing, switch_to_radiative, check_for_redo_MLT

      logical, parameter :: dbg = .false.
      integer, parameter :: kdbg = -1
      
      integer, parameter :: nvbs = num_mlt_partials

      contains


      subroutine set_mlt_vars(s, nzlo, nzhi, ierr)
         use star_utils, only: start_time, update_time
         type (star_info), pointer :: s
         integer, intent(in) :: nzlo, nzhi
         integer, intent(out) :: ierr
         integer :: k, op_err
         integer(8) :: time0
         real(dp) :: total, opacity, gamma1, Cv, chiRho, chiT, Cp, &
            grada, P, xh, gradL_composition_term
         logical :: make_gradr_sticky_in_solver_iters
         include 'formats'
         ierr = 0
         if (dbg) write(*, *) 'doing set_mlt_vars'
         gradL_composition_term = -1d0
         opacity = -1d0
         chiRho = -1d0
         chiT = -1d0
         Cp = -1d0
         grada = -1d0
         P = -1d0
         xh = -1d0 
         if (s% doing_timing) call start_time(s, time0, total)
!$OMP PARALLEL DO PRIVATE(k,op_err,make_gradr_sticky_in_solver_iters) SCHEDULE(dynamic,2)
         do k = nzlo, nzhi
            op_err = 0
            call do1_mlt_2(s, k, s% alpha_mlt(k), gradL_composition_term, &
               opacity, chiRho, chiT, Cp, grada, P, xh, &
               make_gradr_sticky_in_solver_iters, op_err)
            if (op_err /= 0) then
               ierr = op_err
               if (s% report_ierr) write(*,2) 'set_mlt_vars failed', k
            end if
            if (make_gradr_sticky_in_solver_iters .and. s% solver_iter > 3) then
               if (.not. s% fixed_gradr_for_rest_of_solver_iters(k)) &
                  s% fixed_gradr_for_rest_of_solver_iters(k) = &
                     (s% mlt_mixing_type(k) == no_mixing)
            end if            
         end do
!$OMP END PARALLEL DO
         if (s% doing_timing) call update_time(s, time0, total, s% time_mlt)
      end subroutine set_mlt_vars


      subroutine do1_mlt(s, k, mixing_length_alpha, gradL_composition_term_in, &
            opacity_face_in, chiRho_face_in, &
            chiT_face_in, Cp_face_in, grada_face_in, P_face_in, xh_face_in, &
            ierr)
         ! get convection info for point k
         !use mlt_lib
         use eos_def
         use chem_def, only: ih1
         type (star_info), pointer :: s
         integer, intent(in) :: k
         real(dp), intent(in) :: mixing_length_alpha, &
            gradL_composition_term_in, opacity_face_in, &
            chiRho_face_in, chiT_face_in, &
            Cp_face_in, grada_face_in, P_face_in, xh_face_in
         integer, intent(out) :: ierr
         logical :: make_gradr_sticky_in_solver_iters
         call do1_mlt_2(s, k, mixing_length_alpha, gradL_composition_term_in, &
            opacity_face_in, chiRho_face_in, &
            chiT_face_in, Cp_face_in, grada_face_in, P_face_in, xh_face_in, &
            make_gradr_sticky_in_solver_iters, ierr)
      end subroutine do1_mlt


      subroutine do1_mlt_2(s, k, mixing_length_alpha, gradL_composition_term_in, &
            opacity_face_in, chiRho_face_in, &
            chiT_face_in, Cp_face_in, grada_face_in, P_face_in, xh_face_in, &
            make_gradr_sticky_in_solver_iters, ierr)
         ! get convection info for point k
         !use mlt_lib
         use eos_def
         use chem_def, only: ih1
         type (star_info), pointer :: s
         integer, intent(in) :: k
         real(dp), intent(in) :: mixing_length_alpha, &
            gradL_composition_term_in, opacity_face_in, &
            chiRho_face_in, chiT_face_in, &
            Cp_face_in, grada_face_in, P_face_in, xh_face_in
         logical, intent(out) :: make_gradr_sticky_in_solver_iters
         integer, intent(out) :: ierr

         real(dp) :: m, mstar, L, r, dlnm_dlnq, v0, thc, asc, Q_face, &
            a, b, Pgas_div_P_limit, da_dlnd, da_dlnT, db_dlnd, db_dlnT, &
            max_q_for_Pgas_div_P_limit, min_q_for_Pgas_div_P_limit, &
            mlt_basics(num_mlt_results), prev_conv_vel, max_conv_vel, dt, &
            alfa, beta, &
            T_face, rho_face, P_face, Cv_face, gamma1_face, &
            chiRho_face, chiT_face, Cp_face, opacity_face, grada_face, v, &
            cv_old, gradr_factor, d_gradr_factor_dw, f, xh_face, tau_face, &
            d_grada_face_dlnd00, d_grada_face_dlnT00, &
            d_grada_face_dlndm1, d_grada_face_dlnTm1, &
            gradL_composition_term, dlnT, dlnP, &
            abs_du_div_cs, cs, T_00, T_m1, rho_00, rho_m1, P_00, P_m1, &
            chiRho_for_partials_00, chiT_for_partials_00, &
            chiRho_for_partials_m1, chiT_for_partials_m1, &
            chiRho_00, d_chiRho_00_dlnd, d_chiRho_00_dlnT, &
            chiRho_m1, d_chiRho_m1_dlnd, d_chiRho_m1_dlnT, &
            chiT_00, d_chiT_00_dlnd, d_chiT_00_dlnT, &
            chiT_m1, d_chiT_m1_dlnd, d_chiT_m1_dlnT, &
            Cp_00, d_Cp_00_dlnd, d_Cp_00_dlnT, &
            Cp_m1, d_Cp_m1_dlnd, d_Cp_m1_dlnT, &
            opacity_00, d_opacity_00_dlnd, d_opacity_00_dlnT, &
            opacity_m1, d_opacity_m1_dlnd, d_opacity_m1_dlnT, &
            grada_00, d_grada_00_dlnd, d_grada_00_dlnT, &
            grada_m1, d_grada_m1_dlnd, d_grada_m1_dlnT, &
            normal_mlt_gradT_factor
         real(dp), target :: mlt_partials1_ary(num_mlt_partials*num_mlt_results)
         real(dp), pointer :: mlt_partials1(:), mlt_partials(:,:), vel(:)
         integer :: i, mixing_type, h1, nz, k_T_max
         real(dp), parameter :: conv_vel_mach_limit = 0.9d0
         logical :: Schwarzschild_stable, Ledoux_stable
         character (len=32) :: MLT_option
         logical, parameter :: just_gradr = .false.

         include 'formats'

         ierr = 0
         if (s% gamma_law_hydro > 0d0) then  
            call set_no_MLT_results
            return
         end if

         nz = s% nz
         
         if (k < 1 .or. k > nz) then
            write(*,3) 'bad k for do1_mlt', k, nz
            ierr = -1
            return
            call mesa_error(__FILE__,__LINE__)
         end if
         
         MLT_option = s% MLT_option

         mlt_partials1 => mlt_partials1_ary
         mlt_partials(1:num_mlt_partials,1:num_mlt_results) => &
            mlt_partials1(1:num_mlt_partials*num_mlt_results)

         m = s% m_grav(k)
         mstar = s% m_grav(1)

         if (m < 0) then
            write(*,2) 'mlt nz', s% nz
            write(*,2) 's% q(k)', k, s% q(k)
            write(*,2) 's% m(k)', k, s% m(k)
            write(*,2) 's% m_grav(k)', k, s% m_grav(k)
         end if

         dlnm_dlnq = 1
         r = s% r(k)
         L = s% L(k)

         if (is_bad_num(L)) then
            write(*,2) 'do1_mlt L', k, L
            call mesa_error(__FILE__,__LINE__)
         end if

         if (s% rotation_flag .and. s% mlt_use_rotation_correction) then
            gradr_factor = s% ft_rot(k)/s% fp_rot(k)*s% gradr_factor(k)
            if (s% w_div_wc_flag) then
               d_gradr_factor_dw = gradr_factor*(s% dft_rot_dw_div_wc(k)/s%ft_rot(k) &
                  -s% dfp_rot_dw_div_wc(k)/s%fp_rot(k) )
            end if
         else
            gradr_factor = s% gradr_factor(k)
            d_gradr_factor_dw = 0d0
         end if

         if (is_bad_num(gradr_factor)) then
            ierr = -1
            if (s% report_ierr) then
               write(*,2) 'do1_mlt_eval gradr_factor', k, gradr_factor, s% ft_rot(k), s% fp_rot(k)
            end if
            if (s% stop_for_bad_nums) then
               write(*,2) 'gradr_factor', k, gradr_factor, s% ft_rot(k), s% fp_rot(k)
               stop 'do1_mlt_eval'
            end if
            return
         end if

         ! alfa is the fraction coming from k; (1-alfa) from k-1.
         if (k == 1) then
            alfa = 1d0
         else
            alfa = s% dq(k-1)/(s% dq(k-1) + s% dq(k))
         end if
         beta = 1d0 - alfa
         h1 = s% net_iso(ih1)
         
         if (k > 0) then
            d_chiRho_00_dlnd = s% d_eos_dlnd(i_chiRho, k)
            d_chiRho_00_dlnT = s% d_eos_dlnT(i_chiRho, k)
            d_chiT_00_dlnd = s% d_eos_dlnd(i_chiT, k)
            d_chiT_00_dlnT = s% d_eos_dlnT(i_chiT, k)
            d_Cp_00_dlnd = s% d_eos_dlnd(i_Cp, k)
            d_Cp_00_dlnT = s% d_eos_dlnT(i_Cp, k)
            d_grada_00_dlnd = s% d_eos_dlnd(i_grad_ad, k)
            d_grada_00_dlnT = s% d_eos_dlnT(i_grad_ad, k)
            d_opacity_00_dlnd = s% d_opacity_dlnd(k)
            d_opacity_00_dlnT = s% d_opacity_dlnT(k)
         else
            d_chiRho_00_dlnd = 0d0
            d_chiRho_00_dlnT = 0d0
            d_chiT_00_dlnd = 0d0
            d_chiT_00_dlnT = 0d0
            d_Cp_00_dlnd = 0d0
            d_Cp_00_dlnT = 0d0
            d_grada_00_dlnd = 0d0
            d_grada_00_dlnT = 0d0
            d_opacity_00_dlnd = 0d0
            d_opacity_00_dlnT = 0d0
         end if
         
         if (k > 1) then
            d_chiRho_m1_dlnd = s% d_eos_dlnd(i_chiRho, k-1)
            d_chiRho_m1_dlnT = s% d_eos_dlnT(i_chiRho, k-1)
            d_chiT_m1_dlnd = s% d_eos_dlnd(i_chiT, k-1)
            d_chiT_m1_dlnT = s% d_eos_dlnT(i_chiT, k-1)
            d_Cp_m1_dlnd = s% d_eos_dlnd(i_Cp, k-1)
            d_Cp_m1_dlnT = s% d_eos_dlnT(i_Cp, k-1)
            d_grada_m1_dlnd = s% d_eos_dlnd(i_grad_ad, k-1)
            d_grada_m1_dlnT = s% d_eos_dlnT(i_grad_ad, k-1)
            d_opacity_m1_dlnd = s% d_opacity_dlnd(k-1)
            d_opacity_m1_dlnT = s% d_opacity_dlnT(k-1)
         else
            d_chiRho_m1_dlnd = 0d0
            d_chiRho_m1_dlnT = 0d0
            d_chiT_m1_dlnd = 0d0
            d_chiT_m1_dlnT = 0d0
            d_Cp_m1_dlnd = 0d0
            d_Cp_m1_dlnT = 0d0
            d_grada_m1_dlnd = 0d0
            d_grada_m1_dlnT = 0d0
            d_opacity_m1_dlnd = 0d0
            d_opacity_m1_dlnT = 0d0
         end if

         opacity_face = opacity_face_in
         chiRho_face = chiRho_face_in
         chiT_face = chiT_face_in
         Cp_face = Cp_face_in
         grada_face = grada_face_in
         P_face = P_face_in
         xh_face = xh_face_in
         gradL_composition_term = gradL_composition_term_in      
         rho_00 = s% rho(k)
         T_00 = s% T(k)
         P_00 = s% P(k)
         chiRho_00 = s% chiRho(k)
         chiT_00 = s% chiT(k)
         chiRho_for_partials_00 = s% chiRho_for_partials(k)
         chiT_for_partials_00 = s% chiT_for_partials(k)
         Cp_00 = s% Cp(k)
         opacity_00 = s% opacity(k)
         grada_00 = s% grada(k)

         if (alfa == 1d0) then
            
            rho_m1 = 0d0
            T_m1 = 0d0
            P_m1 = 0d0
            chiRho_m1 = 0d0
            chiT_m1 = 0d0
            chiRho_for_partials_m1 = 0d0
            chiT_for_partials_m1 = 0d0
            Cp_m1 = 0d0
            opacity_m1 = 0d0
            grada_m1 = 0d0

            T_face = T_00
            rho_face = rho_00
            tau_face = s% tau_start(k)
            if (P_face < 0) P_face = P_00
            if (chiRho_face < 0) chiRho_face = chiRho_00
            if (chiT_face < 0) chiT_face = chiT_00
            if (Cp_face < 0) Cp_face = Cp_00
            if (opacity_face < 0) opacity_face = opacity_00
            if (grada_face < 0) grada_face = grada_00
            if (h1 /= 0 .and. xh_face < 0) xh_face = s% xa(h1, k)
            s% actual_gradT(k) = 0

         else
         
            rho_m1 = s% rho(k-1)
            T_m1 = s% T(k-1)
            P_m1 = s% P(k-1)
            chiRho_m1 = s% chiRho(k-1)
            chiT_m1 = s% chiT(k-1)
            chiRho_for_partials_m1 = s% chiRho_for_partials(k-1)
            chiT_for_partials_m1 = s% chiT_for_partials(k-1)
            Cp_m1 = s% Cp(k-1)
            opacity_m1 = s% opacity(k-1)
            grada_m1 = s% grada(k-1)

            tau_face = alfa*s% tau_start(k) + beta*s% tau_start(k-1)
            T_face = alfa*T_00 + beta*T_m1
            rho_face = alfa*rho_00 + beta*rho_m1
            if (P_face < 0) P_face = alfa*P_00 + beta*P_m1
            if (chiRho_face < 0) chiRho_face = alfa*chiRho_00 + beta*chiRho_m1
            if (chiT_face < 0) chiT_face = alfa*chiT_00 + beta*chiT_m1
            if (Cp_face < 0) Cp_face = alfa*Cp_00 + beta*Cp_m1
            if (opacity_face < 0) opacity_face = alfa*opacity_00 + beta*opacity_m1
            if (grada_face < 0) grada_face = alfa*grada_00 + beta*grada_m1
            if (h1 /= 0 .and. xh_face < 0) xh_face = alfa*s% xa(h1,k) + beta*s% xa(h1,k-1)
            dlnT = (T_m1 - T_00)/T_face
            dlnP = (P_m1 - P_00)/P_face
            if (abs(dlnP) > 1d-20) then
               s% actual_gradT(k) = dlnT/dlnP
            else
               s% actual_gradT(k) = 0
            end if
         end if

         s% grada_face(k) = alfa*grada_00 + beta*grada_m1
         !s% d_grada_face_dlnd00(k) = alfa*d_grada_00_dlnd
         !s% d_grada_face_dlnT00(k) = alfa*d_grada_00_dlnT
         !if (k == 1) then
         !   s% d_grada_face_dlndm1(k) = 0d0
         !   s% d_grada_face_dlnTm1(k) = 0d0
         !else
         !   s% d_grada_face_dlndm1(k) = beta*d_grada_m1_dlnd
         !   s% d_grada_face_dlnTm1(k) = beta*d_grada_m1_dlnT
         !end if

         if (Cp_face <= 0d0) then
            ierr = -1
            if (.not. s% report_ierr) return
          !$OMP critical (mlt_crit)
            write(*,2) 'Cp_face', k, Cp_face
            write(*,2) 'T_face', k, T_face
            write(*,2) 'rho_face', k, rho_face
            write(*,2) 'P_face', k, P_face
            write(*,2) 'chiRho_face', k, chiRho_face
            write(*,2) 'chiT_face', k, chiT_face
            write(*,2) 'opacity_face', k, opacity_face
            write(*,2) 'grada_face', k, grada_face
            write(*,2) 'tau_face', k, tau_face
            write(*,2) 'Cp_00', k, Cp_00
            write(*,2) 'Cp_m1', k, Cp_m1
            write(*,2) 'alfa', k, alfa
            write(*,2) 'beta', k, beta
            write(*,*) 'MLT_option ', trim(MLT_option)
            call mesa_error(__FILE__,__LINE__)
          !$OMP end critical (mlt_crit)
         end if
         
         tau_face = 1d0 ! disable this for now.

         if (s% RTI_flag .and. tau_face > 0.667d0) then
            if (s% alpha_RTI(k) > 0d0) then ! RTI takes priority over MLT
               call set_no_mixing
               return
            end if
         end if
         
         if (k == 1 .and. s% mlt_make_surface_no_mixing) then
            call set_no_mixing
            return
         end if
         
         if (s% lnT_start(k)/ln10 > s% max_logT_for_mlt) then
            call set_no_mixing
            return
         end if
         
         if (s% no_MLT_below_shock .and. (s%u_flag .or. s%v_flag)) then ! check for outward shock above k
            if (s% u_flag) then
               vel => s% u
            else
               vel => s% v
            end if
            do i=k-1,1,-1
               cs = s% csound(i)
               if (vel(i+1) >= cs .and. vel(i) < cs) then
                  call set_no_mixing
                  return
               end if
            end do
         end if
         
         if (s% no_MLT_below_T_max) then
            k_T_max = maxloc(s% T_start(1:nz),dim=1)
            if (k > k_T_max) then
               call set_no_mixing
               return
            end if
         end if
         
         make_gradr_sticky_in_solver_iters = s% make_gradr_sticky_in_solver_iters
         if (.not. make_gradr_sticky_in_solver_iters .and. &
               s% min_logT_for_make_gradr_sticky_in_solver_iters < 1d20) then
            k_T_max = maxloc(s% lnT_start(1:nz),dim=1)
            make_gradr_sticky_in_solver_iters = &
               (s% lnT_start(k_T_max)/ln10 >= s% min_logT_for_make_gradr_sticky_in_solver_iters)
         end if
         
         if (make_gradr_sticky_in_solver_iters) then
            if (s% fixed_gradr_for_rest_of_solver_iters(k)) then
               call set_no_mixing
               return
            end if
         end if
         
         thc = s% thermohaline_coeff
         asc = s% alpha_semiconvection
         if (s% center_h1 > s% semiconvection_upper_limit_center_h1) asc = 0

         cv_old = -1
         if (s% have_previous_conv_vel .and. .not. s% conv_vel_flag) then
            if (s% generations >= 2) then
               if (.not. is_bad(s% conv_vel_old(k))) &
                  cv_old = s% conv_vel_old(k)
            else if (s% use_previous_conv_vel_from_file) then
               if (.not. is_bad(s% prev_conv_vel_from_file(k))) &
                  cv_old = s% prev_conv_vel_from_file(k)
            end if
         end if
         
         prev_conv_vel = -1
         dt = -1

         max_conv_vel = s% csound_face(k)*s% max_conv_vel_div_csound
         if (prev_conv_vel >= 0) then
            if (must_limit_conv_vel(s,k)) then
               max_conv_vel = prev_conv_vel
            end if
         else if ( &
               s% dt < s% min_dt_for_increases_in_convection_velocity) then
            prev_conv_vel = 0d0
            max_conv_vel = 1d-2*s% dt*s% cgrav(k)
         end if

         if (s% csound_start(k) > 0d0) then
            if (s% u_flag) then        
               abs_du_div_cs = 0d0
               if (s% u_start(k)/1d5 > s% max_v_for_convection) then
                  max_conv_vel = 0d0              
               else if (s% q(k) > s% max_q_for_convection_with_hydro_on) then
                  max_conv_vel = 0d0
               else if ((abs(s% u_start(k))) >= &
                     s% csound_start(k)*s% max_v_div_cs_for_convection) then
                  max_conv_vel = 0d0              
               else
                  if (k == 1) then
                     abs_du_div_cs = 1d99
                  else if (k < nz) then
                     abs_du_div_cs = max(abs(s% u_start(k) - s% u_start(k+1)), &
                         abs(s% u_start(k) - s% u_start(k-1))) / s% csound_start(k)
                  end if
                  if (abs_du_div_cs > s% max_abs_du_div_cs_for_convection) then
                     ! main purpose is to force radiative in shock face
                     max_conv_vel = 0d0
                  end if
               end if
            else if (s% v_flag) then
               if (s% v_start(k)/1d5 > s% max_v_for_convection) then
                  max_conv_vel = 0d0              
               else if (s% q(k) > s% max_q_for_convection_with_hydro_on) then
                  max_conv_vel = 0d0
               else if ((abs(s% v_start(k))) >= &
                     s% csound_start(k)*s% max_v_div_cs_for_convection) then
                  max_conv_vel = 0d0
               end if
            end if
            if (max_conv_vel == 0d0) then
               MLT_option = 'none'
            end if
         end if

         if (s% use_Ledoux_criterion .and. gradL_composition_term < 0) then
            gradL_composition_term = s% gradL_composition_term(k)
         else
            gradL_composition_term = 0d0
         end if

         if (.not. s% conv_vel_flag) then
            normal_mlt_gradT_factor = 1d0
         else if (abs(s% max_q_for_normal_mlt_gradT_full_on - &
                  s% min_q_for_normal_mlt_gradT_full_off) < 1d-10) then
            if (s% q(k) > s% min_q_for_normal_mlt_gradT_full_off) then
               normal_mlt_gradT_factor = 1d0
            else
               normal_mlt_gradT_factor = 0d0
            end if
         else
            normal_mlt_gradT_factor = &
               (s% q(k) - s% min_q_for_normal_mlt_gradT_full_off)/&
               (s% max_q_for_normal_mlt_gradT_full_on - s% min_q_for_normal_mlt_gradT_full_off)
            normal_mlt_gradT_factor = min(1d0, normal_mlt_gradT_factor)
            normal_mlt_gradT_factor = max(0d0, normal_mlt_gradT_factor)
         end if

         call do1_mlt_eval(s, k, &
            s% cgrav(k), m, mstar, r, L, xh_face, &            
            T_face, rho_face, P_face, &
            chiRho_face, chiT_face, &
            Cp_face, opacity_face, grada_face, &            
            alfa, beta, & ! f_face = alfa*f_00 + beta*f_m1
            T_00, T_m1, rho_00, rho_m1, P_00, P_m1, &
            chiRho_for_partials_00, chiT_for_partials_00, &
            chiRho_for_partials_m1, chiT_for_partials_m1, &
            chiRho_00, d_chiRho_00_dlnd, d_chiRho_00_dlnT, &
            chiRho_m1, d_chiRho_m1_dlnd, d_chiRho_m1_dlnT, &
            chiT_00, d_chiT_00_dlnd, d_chiT_00_dlnT, &
            chiT_m1, d_chiT_m1_dlnd, d_chiT_m1_dlnT, &
            Cp_00, d_Cp_00_dlnd, d_Cp_00_dlnT, &
            Cp_m1, d_Cp_m1_dlnd, d_Cp_m1_dlnT, &
            opacity_00, d_opacity_00_dlnd, d_opacity_00_dlnT, &
            opacity_m1, d_opacity_m1_dlnd, d_opacity_m1_dlnT, &
            grada_00, d_grada_00_dlnd, d_grada_00_dlnT, &
            grada_m1, d_grada_m1_dlnd, d_grada_m1_dlnT, &            
            gradr_factor, d_gradr_factor_dw, gradL_composition_term, &
            asc, s% semiconvection_option, thc, s% thermohaline_option, &
            s% dominant_iso_for_thermohaline(k), &
            mixing_length_alpha, s% alt_scale_height_flag, s% remove_small_D_limit, &
            MLT_option, s% Henyey_MLT_y_param, s% Henyey_MLT_nu_param, &
            normal_mlt_gradT_factor, &
            prev_conv_vel, max_conv_vel, dt, tau_face, just_gradr, &
            mixing_type, mlt_basics, mlt_partials1, ierr)
         if (ierr /= 0) then
            if (s% report_ierr) then
!$OMP critical (mlt_info_crit1)
               write(*,*) 'ierr in do1_mlt_eval for k', k
               call show_stuff(.true.)
               stop 
!$OMP end critical (mlt_info_crit1)
            end if
            return
         end if

         s% mlt_mixing_type(k) = mixing_type
         s% mlt_mixing_length(k) = mlt_basics(mlt_Lambda)
         s% mlt_Gamma(k) = mlt_basics(mlt_Gamma)
         s% mlt_D(k) = mlt_basics(mlt_D)
         s% mlt_D_semi(k) = mlt_basics(mlt_D_semi)
         s% mlt_D_thrm(k) = mlt_basics(mlt_D_thrm)
         s% gradr(k) = mlt_basics(mlt_gradr)
         s% scale_height(k) = mlt_basics(mlt_scale_height)
         s% gradL(k) = mlt_basics(mlt_gradL)
         s% mlt_cdc(k) = s% mlt_D(k)*pow2(pi4*r*r*rho_face)

         if ((s% scale_height(k) <= 0d0 .and. MLT_option /= 'none') &
                .or. is_bad_num(s% scale_height(k))) then
            ierr = -1
            if (.not. s% report_ierr) return
!$OMP critical (mlt_info_crit2)
            write(*,2) 's% scale_height(k)', k, s% scale_height(k)
            call show_stuff(.true.)
            write(*,*)
            write(*,2) 's% scale_height(k)', k, s% scale_height(k)
            write(*,2) 's% grada(k)', k, s% grada(k)
            write(*,2) 's% gradr(k)', k, s% gradr(k)
            write(*,2) 's% gradT(k)', k, s% gradT(k)
            write(*,2) 's% gradL(k)', k, s% gradL(k)
            write(*,2) 'max_conv_vel', k, max_conv_vel
            if (s% stop_for_bad_nums) stop 'mlt info'
!$OMP end critical (mlt_info_crit2)
         end if

         call store_gradr_partials

         s% gradT(k) = mlt_basics(mlt_gradT)         
         s% d_gradT_dlnR(k) = mlt_partials(mlt_dlnR, mlt_gradT)
         s% d_gradT_dL(k) = mlt_partials(mlt_dL, mlt_gradT)
         s% d_gradT_dw_div_wc(k) = mlt_partials(mlt_w_div_wc_var, mlt_gradT)
         if (s% conv_vel_flag) then
            s% d_gradT_dln_cvpv0(k) = & ! convert from d_dcv to d_dlncvp0
               mlt_partials(mlt_cv_var, mlt_gradT)*(s% conv_vel(k) + s% conv_vel_v0)
            if (is_bad(s% d_gradT_dln_cvpv0(k))) then
               write(*,2) 's% d_gradT_dln_cvpv0(k)', k, s% d_gradT_dln_cvpv0(k)
               if (s% stop_for_bad_nums) stop 'mlt_info'
            end if
         else
            s% d_gradT_dln_cvpv0(k) = 0d0
         end if
         s% d_gradT_dlnd00(k) = mlt_partials(mlt_dlnd00, mlt_gradT)  
         s% d_gradT_dlnT00(k) = mlt_partials(mlt_dlnT00, mlt_gradT) 
         if (k == 1) then
            s% d_gradT_dlndm1(k) = 0d0
            s% d_gradT_dlnTm1(k) = 0d0
         else
            s% d_gradT_dlndm1(k) = mlt_partials(mlt_dlndm1, mlt_gradT)
            s% d_gradT_dlnTm1(k) = mlt_partials(mlt_dlnTm1, mlt_gradT)
         end if

         s% mlt_vc(k) = mlt_basics(mlt_convection_velocity)     
         s% d_mlt_vc_dlnR(k) = mlt_partials(mlt_dlnR, mlt_convection_velocity)
         s% d_mlt_vc_dL(k) = mlt_partials(mlt_dL, mlt_convection_velocity)
         s% d_mlt_vc_dlnd00(k) = mlt_partials(mlt_dlnd00, mlt_convection_velocity)  
         s% d_mlt_vc_dlnT00(k) = mlt_partials(mlt_dlnT00, mlt_convection_velocity) 
         if (k == 1) then
            s% d_mlt_vc_dlndm1(k) = 0d0
            s% d_mlt_vc_dlnTm1(k) = 0d0
         else
            s% d_mlt_vc_dlndm1(k) = mlt_partials(mlt_dlndm1, mlt_convection_velocity)
            s% d_mlt_vc_dlnTm1(k) = mlt_partials(mlt_dlnTm1, mlt_convection_velocity)
         end if

         if (mixing_type == 0 .and. s% mlt_vc(k) /= 0d0) then
            write(*,2) 'mixing_type mlt_vc', mixing_type, s% mlt_vc(k)
            call mesa_error(__FILE__,__LINE__)
         end if

         Schwarzschild_stable = (s% gradr(k) < grada_face)
         Ledoux_stable = (s% gradr(k) < s% gradL(k))

         if (s% mlt_gradT_fraction >= 0d0 .and. s% mlt_gradT_fraction <= 1d0) then
            f = s% mlt_gradT_fraction
         else
            f = s% adjust_mlt_gradT_fraction(k)
         end if
         call adjust_gradT_fraction(s, k, f)

         ! Note that L_conv can be negative when conv_vel /= 0 in a convectively
         ! stable region. This can happen when using conv_vel as a variable
         ! Note make_brown_dwarf can have L=0 which means gradr = 0
         if (mlt_option /= 'none' .and. abs(s% gradr(k))>0d0) then
            s% L_conv(k) = s% L(k) * (1d0 - s% gradT(k)/s% gradr(k)) ! C&G 14.109
         else
            s% L_conv(k) = 0d0
         end if
         
         if (k == 1 .or. mlt_option == 'none') then
            s% grad_superad(k) = 0d0
         else
            Q_face = chiT_face/(T_face*chiRho_face)
            s% grad_superad(k) = &
               4*pi*r*r*s% scale_height(k)*rho_face* &
                  (Q_face/Cp_face*(s% P(k-1)-s% P(k)) - (s% lnT(k-1)-s% lnT(k)))/s% dm_bar(k)
            ! grad_superad = area*Hp_face*rho_face*(Q_face/Cp_face*dP - dlogT)/dmbar
            ! Q_face = chiT_face/(T_face*chiRho_face)
            if (abs(s% lnP(k-1)-s% lnP(k)) < 1d-10) then
               s% grad_superad_actual(k) = 0
            else
               s% grad_superad_actual(k) = &
                  (s% lnT(k-1)-s% lnT(k))/(s% lnP(k-1)-s% lnP(k)) - grada_face
            end if
         end if

         if (is_bad_num(s% d_gradT_dlnT00(k))) then
            if (s% report_ierr) then
               write(*,2) 's% d_gradT_dlnT00(k)', k, s% d_gradT_dlnT00(k)
               return
            end if
            if (s% stop_for_bad_nums) then
!$OMP critical (mlt_info_crit3)
               write(*,2) 's% d_gradT_dlnT00(k)', k, s% d_gradT_dlnT00(k)
               call show_stuff(.true.)
               stop 'mlt info'
!$OMP end critical (mlt_info_crit3)
            end if
            ierr = -1
            return
         end if
         
         !if (k == 100) then
         !   call show_stuff(.true.)
         !   call mesa_error(__FILE__,__LINE__)
         !end if
         
         !if (k == 738) write(*,4) 'gradT', k, s% solver_iter, mixing_type, s% gradT(k)
         
         !if (.false. .and. k == s% solver_test_partials_k .and. &
         !      s% solver_iter == s% hydro_dump_iter_number) then
         !   call show_stuff(.true.)
         !   call mesa_error(__FILE__,__LINE__)
         !end if

         contains
         
         subroutine get_mlt_eval_gradr_info(ierr)
            !use mlt_lib, only: mlt_eval_gradr_info
            integer, intent(out) :: ierr
            logical, parameter :: just_get_gradr = .true.
            include 'formats'

            call do1_mlt_eval(s, k, &
               s% cgrav(k), m, mstar, r, L, xh_face, &            
               T_face, rho_face, P_face, &
               chiRho_face, chiT_face, &
               Cp_face, opacity_face, grada_face, &            
               alfa, beta, & ! f_face = alfa*f_00 + beta*f_m1
               T_00, T_m1, rho_00, rho_m1, P_00, P_m1, &
               chiRho_for_partials_00, chiT_for_partials_00, &
               chiRho_for_partials_m1, chiT_for_partials_m1, &
               chiRho_00, d_chiRho_00_dlnd, d_chiRho_00_dlnT, &
               chiRho_m1, d_chiRho_m1_dlnd, d_chiRho_m1_dlnT, &
               chiT_00, d_chiT_00_dlnd, d_chiT_00_dlnT, &
               chiT_m1, d_chiT_m1_dlnd, d_chiT_m1_dlnT, &
               Cp_00, d_Cp_00_dlnd, d_Cp_00_dlnT, &
               Cp_m1, d_Cp_m1_dlnd, d_Cp_m1_dlnT, &
               opacity_00, d_opacity_00_dlnd, d_opacity_00_dlnT, &
               opacity_m1, d_opacity_m1_dlnd, d_opacity_m1_dlnT, &
               grada_00, d_grada_00_dlnd, d_grada_00_dlnT, &
               grada_m1, d_grada_m1_dlnd, d_grada_m1_dlnT, &            
               gradr_factor, d_gradr_factor_dw, gradL_composition_term, &
               asc, s% semiconvection_option, thc, s% thermohaline_option, &
               s% dominant_iso_for_thermohaline(k), &
               mixing_length_alpha, s% alt_scale_height_flag, s% remove_small_D_limit, &
               MLT_option, s% Henyey_MLT_y_param, s% Henyey_MLT_nu_param, &
               normal_mlt_gradT_factor, &
               prev_conv_vel, max_conv_vel, dt, tau_face, just_get_gradr, &
               mixing_type, mlt_basics, mlt_partials1, ierr)
            if (ierr /= 0) return
            s% gradr(k) = mlt_basics(mlt_gradr)
            call store_gradr_partials
            if (is_bad(s% gradr(k))) then
               ierr = -1
               if (.not. s% report_ierr) return
!$OMP critical (mlt_info_crit4)
               write(*,2) 's% gradr(k)', k, s% gradr(k)
               write(*,2) 'P_face', k, P_face
               write(*,2) 'opacity_face', k, opacity_face
               write(*,2) 'L', k, L
               write(*,2) 'm', k, m
               write(*,2) 's% cgrav(k)', k, s% cgrav(k)
               write(*,2) 'tau_face', k, tau_face
               write(*,2) 'T_face', k, T_face
               write(*,2) 'r', k, r
               write(*,2) 'rho_face', k, rho_face
               if (s% stop_for_bad_nums) stop 'get_mlt_eval_gradr_info'
!$OMP end critical (mlt_info_crit4)
            end if 
         end subroutine get_mlt_eval_gradr_info

         
         subroutine store_gradr_partials
            s% d_gradr_dlnR(k) = mlt_partials(mlt_dlnR, mlt_gradr)
            s% d_gradr_dL(k) = mlt_partials(mlt_dL, mlt_gradr)
            s% d_gradr_dw_div_wc(k) = mlt_partials(mlt_w_div_wc_var, mlt_gradr)
            s% d_gradr_dlnd00(k) = mlt_partials(mlt_dlnd00, mlt_gradr)
            s% d_gradr_dlnT00(k) = mlt_partials(mlt_dlnT00, mlt_gradr)
            if (k == 1) then
               s% d_gradr_dlndm1(k) = 0d0
               s% d_gradr_dlnTm1(k) = 0d0
            else
               s% d_gradr_dlndm1(k) = mlt_partials(mlt_dlndm1, mlt_gradr)
               s% d_gradr_dlnTm1(k) = mlt_partials(mlt_dlnTm1, mlt_gradr)
            end if
         end subroutine store_gradr_partials


         subroutine show_stuff(with_results)
            logical, intent(in) :: with_results
            real(dp) :: vsem, Lambda, D, radiative_conductivity
            include 'formats'
            write(*,*)
            write(*,*) 'do1_mlt info for k, nz', k, s% nz
            write(*,2) 's% model_number', s% model_number
            write(*,2) 's% solver_iter', s% solver_iter
            write(*,*)
            write(*,1) 'cgrav =', s% cgrav(k)
            write(*,1) 'm =', m
            write(*,1) 'r =', r
            write(*,1) 'T =', T_face
            write(*,1) 'rho =', rho_face
            write(*,1) 'L =', L
            write(*,1) 'P =', P_face
            write(*,1) 'chiRho =', chiRho_face
            write(*,1) 'chiT =', chiT_face
            write(*,1) 'Cp =', Cp_face
            write(*,1) 'X =', xh_face
            write(*,1) 'opacity =', opacity_face
            write(*,1) 'grada =', grada_face
            write(*,*)
            write(*,1) 'gradr_factor =', gradr_factor
            write(*,1) 'gradL_composition_term =', s% gradL_composition_term(k)
            write(*,*)
            write(*,1) 'alpha_semiconvection =', asc
            write(*,'(a)') 'semiconvection_option = "' // trim(s% semiconvection_option) // '" '
            write(*,*)
            write(*,1) 'thermohaline_coeff =', thc
            write(*,'(a)') 'thermohaline_option = "' // trim(s% thermohaline_option) // '"'
            write(*,2) 'dominant_iso_for_thermohaline =', s% dominant_iso_for_thermohaline(k)
            write(*,*)
            write(*,1) 'mixing_length_alpha =', mixing_length_alpha
            if (s% alt_scale_height_flag) then
               write(*,'(a50)') '         alt_scale_height = .true.'
            else
               write(*,'(a50)') '         alt_scale_height = .false.'
            end if
            write(*,*)
            write(*,1) 'Henyey_y_param =', s% Henyey_MLT_y_param
            write(*,1) 'Henyey_nu_param =', s% Henyey_MLT_nu_param
            write(*,*)
            write(*,'(a)') "MLT_option = '" // trim(s% MLT_option) // "'"
            write(*,*)
            write(*,1) 'prev_conv_vel =', prev_conv_vel
            write(*,1) 'max_conv_vel =', min(1d99,max_conv_vel)
            write(*,*)
            write(*,1) 'dt =', dt
            write(*,1) 'tau =', tau_face
            write(*,*)
            write(*,*) '--------------------------------------'
            write(*,*)
            write(*,*)
            write(*,*)

            write(*,1) 'logRho =', s% lnd(k)/ln10
            write(*,1) 'logT =', s% lnT(k)/ln10
            write(*,1) 'x =', s% x(k)
            write(*,1) 'z =', 1d0 - (s% x(k) + s% y(k))
            write(*,1) 'abar =', s% abar(k)
            write(*,1) 'zbar =', s% zbar(k)
            write(*,*)
            write(*,*)
            write(*,3) 'k, nz', k, s% nz
            write(*,*)
            write(*,*)
            if (k > 1) then
               write(*,2) 's% opacity(k)', k, s% opacity(k)
               write(*,2) 's% opacity(k-1)', k-1, s% opacity(k-1)
               write(*,1) 'alfa', alfa
               write(*,1) 'beta', beta
               write(*,1) 'alfa', alfa*s% opacity(k)
               write(*,1) 'beta', beta*s% opacity(k-1)
               write(*,1) 'opacity_face', opacity_face
            end if

            if (ierr /= 0 .or. .not. with_results) return
            write(*,1) 's% gradr(k)', s% gradr(k)
            write(*,1) 's% gradT(k)', s% gradT(k)
            write(*,1) 's% gradL(k)', s% gradL(k)
            write(*,1) 's% gradL(k) - grada_face', s% gradL(k) - grada_face
            write(*,*)
            write(*,1) 's% mlt_D(k)', s% mlt_D(k)
            write(*,1) 's% mlt_D_semi(k)', s% mlt_D_semi(k)
            write(*,1) 's% mlt_D_thrm(k)', s% mlt_D_thrm(k)
            write(*,1) 's% mlt_vc(k)', s% mlt_vc(k)
            write(*,2) 's% mlt_mixing_type(k)', s% mlt_mixing_type(k)
            write(*,1) 's% mlt_mixing_length(k)', s% mlt_mixing_length(k)
            write(*,1) 's% d_gradT_dlnd00(k)', s% d_gradT_dlnd00(k)
            write(*,1) 's% d_gradT_dlnT00(k)', s% d_gradT_dlnT00(k)
            write(*,1) 's% d_gradT_dlndm1(k)', s% d_gradT_dlndm1(k)
            write(*,1) 's% d_gradT_dlnTm1(k)', s% d_gradT_dlnTm1(k)
            write(*,1) 's% d_gradT_dlnR(k)', s% d_gradT_dlnR(k)
            write(*,1) 's% d_gradT_dL(k)', s% d_gradT_dL(k)
            write(*,*)
            write(*,1) 's% d_gradr_dlnd00(k)', s% d_gradr_dlnd00(k)
            write(*,1) 's% d_gradr_dlnT00(k)', s% d_gradr_dlnT00(k)
            write(*,1) 's% d_gradr_dlndm1(k)', s% d_gradr_dlndm1(k)
            write(*,1) 's% d_gradr_dlnTm1(k)', s% d_gradr_dlnTm1(k)
            write(*,1) 's% d_gradr_dlnR(k)', s% d_gradr_dlnR(k)
            write(*,1) 's% d_gradr_dL(k)', s% d_gradr_dL(k)
            write(*,*)
            write(*,*) 'Schwarzschild_stable', Schwarzschild_stable
            write(*,*) 'Ledoux_stable', Ledoux_stable
            write(*,*)

         end subroutine show_stuff

         subroutine set_no_MLT_results()
            s% mlt_mixing_type(k) = no_mixing
            s% mlt_mixing_length(k) = 0d0
            s% mlt_vc(k) = 0d0
            s% mlt_Gamma(k) = 0d0
            s% grada_face(k) = 0d0
            if (s% zero_gravity) then
               s% scale_height(k) = 0
            else
               s% scale_height(k) = P_face*r*r/(s% cgrav(k)*m*rho_face)
            end if
            s% gradL(k) = 0d0
            s% L_conv(k) = 0d0
            s% gradT(k) = 0d0
            s% d_gradT_dlnR(k) = 0d0
            s% d_gradT_dL(k) = 0d0
            s% d_gradT_dw_div_wc(k) = 0d0
            if (s% conv_vel_flag) s% d_gradT_dln_cvpv0(k) = 0d0
            s% d_gradT_dlnd00(k) = 0d0
            s% d_gradT_dlnT00(k) = 0d0
            s% d_gradT_dlndm1(k) = 0d0
            s% d_gradT_dlnTm1(k) = 0d0
            s% mlt_D(k) = 0d0
            s% mlt_D_semi(k) = 0d0
            s% mlt_D_thrm(k) = 0d0
            s% mlt_cdc(k) = 0d0
            s% actual_gradT(k) = 0
            s% grad_superad(k) = 0
         end subroutine set_no_MLT_results

         subroutine set_no_mixing()
            call get_mlt_eval_gradr_info(ierr)
            if (ierr /= 0) return
            s% mlt_mixing_type(k) = no_mixing
            s% mlt_mixing_length(k) = 0d0
            s% mlt_vc(k) = 0d0
            s% mlt_Gamma(k) = 0d0
            s% grada_face(k) = 0d0
            s% scale_height(k) = P_face*r*r/(s% cgrav(k)*m*rho_face)
            s% gradL(k) = 0d0
            s% L_conv(k) = 0d0
            s% gradT(k) = s% gradr(k)
            s% d_gradT_dlnR(k) = s% d_gradr_dlnR(k)
            s% d_gradT_dL(k) = s% d_gradr_dL(k)
            s% d_gradT_dw_div_wc(k) = s% d_gradr_dw_div_wc(k)
            if (s% conv_vel_flag) s% d_gradT_dln_cvpv0(k) = 0d0
            s% d_gradT_dlnd00(k) = s% d_gradr_dlnd00(k)
            s% d_gradT_dlnT00(k) = s% d_gradr_dlnT00(k)
            s% d_gradT_dlndm1(k) = s% d_gradr_dlndm1(k)
            s% d_gradT_dlnTm1(k) = s% d_gradr_dlnTm1(k)
            s% mlt_D(k) = 0d0
            s% mlt_D_semi(k) = 0d0
            s% mlt_D_thrm(k) = 0d0
            s% mlt_cdc(k) = 0d0
            s% actual_gradT(k) = 0
            s% grad_superad(k) = 0
         end subroutine set_no_mixing

      end subroutine do1_mlt_2


      logical function must_limit_conv_vel(s,k0)
         type (star_info), pointer :: s
         integer, intent(in) :: k0
         real(dp) :: alfa, beta, one_m_f
         integer :: k, wdth
         include 'formats'
         must_limit_conv_vel = .false.
         if (s% q(k0) <= s% max_q_for_limit_conv_vel .or. &
             s% m(k0) <= s% max_mass_in_gm_for_limit_conv_vel .or. &
             s% r(k0) <= s% max_r_in_cm_for_limit_conv_vel) then
            must_limit_conv_vel = .true.
            return
         end if
         if (.not. s% v_flag) return
         wdth = s% width_for_limit_conv_vel
         if (wdth < 0) return
         do k = max(2,k0-wdth),min(s% nz,k0+wdth)
            if (s% csound(k) < s% v(k) .and. s% v(k) <= s% csound(k-1)) then
               must_limit_conv_vel = .true.
               return
            end if
         end do
      end function must_limit_conv_vel


      subroutine adjust_gradT_fraction(s,k,f)
         ! replace gradT by combo of grada_face and gradr
         ! then check excess
         use eos_def
         type (star_info), pointer :: s
         real(dp), intent(in) :: f
         integer, intent(in) :: k

         real(dp) :: alfa, beta, one_m_f

         include 'formats'

         if (f >= 0.0 .and. f <= 1.0) then

            ! alfa is the fraction coming from k; (1-alfa) from k-1.
            if (k == 1) then
               alfa = 1.0d0
            else
               alfa = s% dq(k-1)/(s% dq(k-1) + s% dq(k))
            end if
            beta = 1.0d0 - alfa

            if (f == 0d0) then
               s% gradT(k) = s% gradr(k)
               s% d_gradT_dlnR(k) = s% d_gradr_dlnR(k)
               s% d_gradT_dL(k) = s% d_gradr_dL(k)
               s% d_gradT_dw_div_wc(k) = s% d_gradr_dw_div_wc(k)
               s% d_gradT_dlnd00(k) = s% d_gradr_dlnd00(k)
               s% d_gradT_dlnT00(k) = s% d_gradr_dlnT00(k)
               if (k > 1) then
                  s% d_gradT_dlndm1(k) = s% d_gradr_dlndm1(k)
                  s% d_gradT_dlnTm1(k) = s% d_gradr_dlnTm1(k)
               end if
            else ! mix
               one_m_f = 1.0d0 - f
               s% gradT(k) = f*s% grada_face(k) + one_m_f*s% gradr(k)
               s% d_gradT_dlnR(k) = one_m_f*s% d_gradr_dlnR(k)
               s% d_gradT_dL(k) = one_m_f*s% d_gradr_dL(k)
               s% d_gradT_dw_div_wc(k) = one_m_f*s% d_gradr_dw_div_wc(k)
               s% d_gradT_dlnd00(k) = &
                  f*alfa*s% d_eos_dlnd(i_grad_ad, k) + one_m_f*s% d_gradr_dlnd00(k)
               s% d_gradT_dlnT00(k) = &
                  f*alfa*s% d_eos_dlnT(i_grad_ad, k) + one_m_f*s% d_gradr_dlnT00(k)
               if (k > 1) then
                  s% d_gradT_dlndm1(k) = &
                     f*beta*s% d_eos_dlnd(i_grad_ad, k-1) + one_m_f*s% d_gradr_dlndm1(k)
                  s% d_gradT_dlnTm1(k) = &
                     f*beta*s% d_eos_dlnT(i_grad_ad, k-1) + one_m_f*s% d_gradr_dlnTm1(k)
               end if
            end if
            if (s% conv_vel_flag) s% d_gradT_dln_cvpv0(k) = 0.0d0

         end if

! fxt 02jun2019
! gradT_sub_grada was saved before calling adjust_gradT_excess,
! but adjust_gradT_excess which adjusts gradT(k), making gradT(k) inconsistent with gradT_sub_grada
!         s% gradT_sub_grada(k) = s% gradT(k) - s% grada_face(k) ! gradT_excess
!         call adjust_gradT_excess(s, k)

! just recalculate gradT_sub_grada after calling adjust_gradT_excess
         s% gradT_sub_grada(k) = s% gradT(k) - s% grada_face(k) ! gradT_excess
         call adjust_gradT_excess(s, k)
         s% gradT_sub_grada(k) = s% gradT(k) - s% grada_face(k) ! new gradT_excess from adjusted gradT

      end subroutine adjust_gradT_fraction


      subroutine adjust_gradT_excess(s, k)
         use eos_def
         type (star_info), pointer :: s
         integer, intent(in) :: k

         real(dp) :: alfa, beta, log_tau, gradT_excess_alpha, &
            d_grada_face_dlnd00, d_grada_face_dlnT00, &
            d_grada_face_dlndm1, d_grada_face_dlnTm1

         include 'formats'

         !s% gradT_excess_alpha is calculated at start of step and held constant during iterations
         ! gradT_excess_alpha = 0 means no efficiency boost; = 1 means full efficiency boost

         gradT_excess_alpha = s% gradT_excess_alpha
         s% gradT_excess_effect(k) = 0.0d0

         if (gradT_excess_alpha <= 0.0  .or. &
             s% gradT_sub_grada(k) <= s% gradT_excess_f1) return

         if (s% lnT(k)/ln10 > s% gradT_excess_max_logT) return

         log_tau = log10(s% tau(k))
         if (log_tau < s% gradT_excess_max_log_tau_full_off) return

         ! boost efficiency of energy transport

         ! alfa is the fraction coming from k; (1-alfa) from k-1.
         if (k == 1) then
            alfa = 1.0d0
         else
            alfa = s% dq(k-1)/(s% dq(k-1) + s% dq(k))
         end if
         beta = 1.0d0 - alfa

         ! grada_face = alfa*s% grada(k) + beta*s% grada(k-1)
         d_grada_face_dlnd00 = alfa*s% d_eos_dlnd(i_grad_ad, k)
         d_grada_face_dlnT00 = alfa*s% d_eos_dlnT(i_grad_ad, k)
         if (k > 1) then
            d_grada_face_dlndm1 = beta*s% d_eos_dlnd(i_grad_ad, k-1)
            d_grada_face_dlnTm1 = beta*s% d_eos_dlnT(i_grad_ad, k-1)
         else
            d_grada_face_dlndm1 = 0.0d0
            d_grada_face_dlnTm1 = 0.0d0
         end if

         if (log_tau < s% gradT_excess_min_log_tau_full_on) &
            gradT_excess_alpha = gradT_excess_alpha* &
               (log_tau - s% gradT_excess_max_log_tau_full_off)/ &
               (s% gradT_excess_min_log_tau_full_on - s% gradT_excess_max_log_tau_full_off)

         alfa = s% gradT_excess_f2 ! for full boost, use this fraction of gradT
         if (gradT_excess_alpha < 1) then ! only partial boost, so increase alfa
            ! alfa goes to 1 as gradT_excess_alpha goes to 0
            ! alfa unchanged as gradT_excess_alpha goes to 1
            alfa = alfa + (1d0 - alfa)*(1d0 - gradT_excess_alpha)
         end if
         beta = 1.d0 - alfa

         s% gradT(k) = alfa*s% gradT(k) + beta*s% grada_face(k)
         s% gradT_excess_effect(k) = beta

         s% d_gradT_dlnR(k) = alfa*s% d_gradT_dlnR(k)
         s% d_gradT_dL(k) = alfa*s% d_gradT_dL(k)
         s% d_gradT_dw_div_wc(k) = alfa*s% d_gradT_dw_div_wc(k)
         if (s% conv_vel_flag) s% d_gradT_dln_cvpv0(k) = alfa*s% d_gradT_dln_cvpv0(k)

         s% d_gradT_dlnd00(k) = &
            alfa*s% d_gradT_dlnd00(k) + beta*d_grada_face_dlnd00
         s% d_gradT_dlnT00(k) = &
            alfa*s% d_gradT_dlnT00(k) + beta*d_grada_face_dlnT00

         if (k > 1) then
            s% d_gradT_dlndm1(k) = &
               alfa*s% d_gradT_dlndm1(k) + beta*d_grada_face_dlndm1
            s% d_gradT_dlnTm1(k) = &
               alfa*s% d_gradT_dlnTm1(k) + beta*d_grada_face_dlnTm1
         end if

      end subroutine adjust_gradT_excess


      subroutine set_grads(s, ierr)
         use chem_def, only: chem_isos
         use star_utils, only: smooth
         type (star_info), pointer :: s
         integer, intent(out) :: ierr

         integer :: k, nz, j, cid, max_cid
         real(dp) :: val, max_val, A, Z
         real(dp), pointer, dimension(:) :: dlnP, dlnd, dlnT

         include 'formats'

         ierr = 0
         nz = s% nz
         call do_alloc(ierr)
         if (ierr /= 0) return

         do k = 2, nz
            dlnP(k) = s% lnP(k-1) - s% lnP(k)
            dlnd(k) = s% lnd(k-1) - s% lnd(k)
            dlnT(k) = s% lnT(k-1) - s% lnT(k)
         end do
         dlnP(1) = dlnP(2)
         dlnd(1) = dlnd(2)
         dlnT(1) = dlnT(2)

         call smooth(dlnP,nz)
         call smooth(dlnd,nz)
         call smooth(dlnT,nz)

         s% grad_density(1) = 0
         s% grad_temperature(1) = 0
         do k = 2, nz
            if (dlnP(k) >= 0) then
               s% grad_density(k) = 0
               s% grad_temperature(k) = 0
            else
               s% grad_density(k) = dlnd(k)/dlnP(k)
               s% grad_temperature(k) = dlnT(k)/dlnP(k)
            end if
         end do

         call smooth(s% grad_density,nz)
         call smooth(s% grad_temperature,nz)

         if (s% use_Ledoux_criterion) then
            do k=1,nz
               s% gradL_composition_term(k) = s% unsmoothed_brunt_B(k)
            end do
            call smooth_gradL_composition_term
         else
            do k=1,nz
               s% gradL_composition_term(k) = 0d0
            end do
         end if

         call dealloc

         do k=3,nz-2
            max_cid = 0
            max_val = -1d99
            do j=1,s% species
               cid = s% chem_id(j)
               A = dble(chem_isos% Z_plus_N(cid))
               Z = dble(chem_isos% Z(cid))
               val = (s% xa(j,k-2) + s% xa(j,k-1) - s% xa(j,k) - s% xa(j,k+1))*(1d0 + Z)/A
               if (val > max_val) then
                  max_val = val
                  max_cid = cid
               end if
            end do
            s% dominant_iso_for_thermohaline(k) = max_cid
         end do
         s% dominant_iso_for_thermohaline(1:2) = &
            s% dominant_iso_for_thermohaline(3)
         s% dominant_iso_for_thermohaline(nz-1:nz) = &
            s% dominant_iso_for_thermohaline(nz-2)


         contains

         subroutine smooth_gradL_composition_term
            use star_utils, only: weighed_smoothing, threshold_smoothing
            logical, parameter :: preserve_sign = .false.
            real(dp), pointer, dimension(:) :: work
            integer :: k
            include 'formats'
            ierr = 0
            work => dlnd
            if (s% num_cells_for_smooth_gradL_composition_term <= 0) return
            call threshold_smoothing( &
               s% gradL_composition_term, s% threshold_for_smooth_gradL_composition_term, s% nz, &
               s% num_cells_for_smooth_gradL_composition_term, preserve_sign, work)
         end subroutine smooth_gradL_composition_term

         subroutine do_alloc(ierr)
            integer, intent(out) :: ierr
            call do_work_arrays(.true.,ierr)
         end subroutine do_alloc

         subroutine dealloc
            call do_work_arrays(.false.,ierr)
         end subroutine dealloc

         subroutine do_work_arrays(alloc_flag, ierr)
            use alloc, only: work_array
            logical, intent(in) :: alloc_flag
            integer, intent(out) :: ierr
            logical, parameter :: crit = .false.
            ierr = 0
            call work_array(s, alloc_flag, crit, &
               dlnP, nz, nz_alloc_extra, 'mlt', ierr)
            if (ierr /= 0) return
            call work_array(s, alloc_flag, crit, &
               dlnd, nz, nz_alloc_extra, 'mlt', ierr)
            if (ierr /= 0) return
            call work_array(s, alloc_flag, crit, &
               dlnT, nz, nz_alloc_extra, 'mlt', ierr)
            if (ierr /= 0) return
         end subroutine do_work_arrays

      end subroutine set_grads


      subroutine switch_to_no_mixing(s,k)
         type (star_info), pointer :: s
         integer, intent(in) :: k
         s% mlt_mixing_type(k) = no_mixing
         s% mlt_mixing_length(k) = 0
         s% mlt_D(k) = 0
         s% mlt_D_semi(k) = 0
         s% mlt_D_thrm(k) = 0
         s% mlt_cdc(k) = 0d0
         s% mlt_vc(k) = 0
      end subroutine switch_to_no_mixing


      subroutine switch_to_radiative(s,k)
         type (star_info), pointer :: s
         integer, intent(in) :: k
         s% gradT(k) = s% gradr(k)
         s% d_gradT_dlnd00(k) = s% d_gradr_dlnd00(k)
         s% d_gradT_dlnT00(k) = s% d_gradr_dlnT00(k)
         s% d_gradT_dlndm1(k) = s% d_gradr_dlndm1(k)
         s% d_gradT_dlnTm1(k) = s% d_gradr_dlnTm1(k)
         s% d_gradT_dlnR(k) = s% d_gradr_dlnR(k)
         s% d_gradT_dL(k) = s% d_gradr_dL(k)
         if (s% conv_vel_flag) s% d_gradT_dln_cvpv0(k) = 0d0
         s% d_gradT_dw_div_wc(k) = s% d_gradr_dw_div_wc(k)
      end subroutine switch_to_radiative


      subroutine switch_to_adiabatic(s,k)
         use eos_def, only: i_grad_ad
         type (star_info), pointer :: s
         integer, intent(in) :: k
         s% gradT(k) = s% grada(k)
         s% d_gradT_dlnd00(k) = s% d_eos_dlnd(i_grad_ad, k)
         s% d_gradT_dlnT00(k) = s% d_eos_dlnT(i_grad_ad, k)
         s% d_gradT_dlndm1(k) = 0
         s% d_gradT_dlnTm1(k) = 0
         s% d_gradT_dlnR(k) = 0
         s% d_gradT_dL(k) = 0
         if (s% conv_vel_flag) s% d_gradT_dln_cvpv0(k) = 0d0
         s% d_gradT_dw_div_wc(k) = 0
      end subroutine switch_to_adiabatic


      subroutine set_gradT_excess_alpha(s, ierr)
         use alloc
         use star_utils, only: get_Lrad_div_Ledd, after_C_burn
         use chem_def, only: ih1, ihe4

         type (star_info), pointer :: s
         integer, intent(out) :: ierr

         real(dp) :: beta, lambda, phi, tmp, alpha, alpha2
         real(dp) :: &
            beta_limit, &
            lambda1, &
            beta1, &
            lambda2, &
            beta2, &
            dlambda, &
            dbeta

         integer :: k, k_beta, k_lambda, nz, h1, he4

         logical, parameter :: dbg = .false.

         include 'formats'

         if (dbg) write(*,*) 'enter set_gradT_excess_alpha'

         ierr = 0
         if (.not. s% okay_to_reduce_gradT_excess) then
            s% gradT_excess_alpha = 0
            if (dbg) write(*,1) 'okay_to_reduce_gradT_excess'
            return
         end if
         nz = s% nz

         h1 = s% net_iso(ih1)
         if (h1 /= 0) then
            if (s% xa(h1,nz) > s% gradT_excess_max_center_h1) then
               s% gradT_excess_alpha = 0
               if (dbg) write(*,1) 'gradT_excess_max_center_h1'
               return
            end if
         end if

         he4 = s% net_iso(ihe4)
         if (he4 /= 0) then
            if (s% xa(he4,nz) < s% gradT_excess_min_center_he4) then
               s% gradT_excess_alpha = 0
               if (dbg) write(*,1) 'gradT_excess_min_center_he4'
               return
            end if
         end if

         beta = 1d0 ! beta = min over k of Pgas(k)/P(k)
         k_beta = 0
         do k=1,nz
            tmp = s% Pgas(k)/s% P(k)
            if (tmp < beta) then
               k_beta = k
               beta = tmp
            end if
         end do

         beta = beta*(1d0 + s% xa(1,nz))

         s% gradT_excess_min_beta = beta
         if (dbg) write(*,2) 'gradT_excess_min_beta', k_beta, beta

         lambda = 0d0 ! lambda = max over k of Lrad(k)/Ledd(k)
         do k=2,k_beta
            tmp = get_Lrad_div_Ledd(s,k)
            if (tmp > lambda) then
               k_lambda = k
               lambda = tmp
            end if
         end do
         lambda = min(1d0,lambda)
         s% gradT_excess_max_lambda = lambda
         if (dbg) write(*,2) 'gradT_excess_max_lambda', k_lambda, lambda

         lambda1 = s% gradT_excess_lambda1
         beta1 = s% gradT_excess_beta1
         lambda2 = s% gradT_excess_lambda2
         beta2 = s% gradT_excess_beta2
         dlambda = s% gradT_excess_dlambda
         dbeta = s% gradT_excess_dbeta

         if (dbg) then
            write(*,1) 'lambda1', lambda1
            write(*,1) 'lambda2', lambda2
            write(*,1) 'lambda', lambda
            write(*,*)
            write(*,1) 'beta1', beta1
            write(*,1) 'beta2', beta2
            write(*,1) 'beta', beta
            write(*,*)
         end if

         ! alpha is fraction of full boost to apply
         ! depends on location in (beta,lambda) plane

         if (lambda1 < 0) then
            alpha = 1
         else if (lambda >= lambda1) then
            if (beta <= beta1) then
               alpha = 1
            else if (beta < beta1 + dbeta) then
               alpha = (beta1 + dbeta - beta)/dbeta
            else ! beta >= beta1 + dbeta
               alpha = 0
            end if
         else if (lambda >= lambda2) then
            beta_limit = beta2 + &
               (lambda - lambda2)*(beta1 - beta2)/(lambda1 - lambda2)
            if (beta <= beta_limit) then
               alpha = 1
            else if (beta < beta_limit + dbeta) then
               alpha = (beta_limit + dbeta - beta)/dbeta
            else
               alpha = 0
            end if
         else if (lambda > lambda2 - dlambda) then
            if (beta <= beta2) then
               alpha = 1
            else if (beta < beta2 + dbeta) then
               alpha = (lambda - (lambda2 - dlambda))/dlambda
            else ! beta >= beta2 + dbeta
               alpha = 0
            end if
         else ! lambda <= lambda2 - dlambda
            alpha = 0
         end if

         if (s% generations > 1 .and. lambda1 >= 0) then ! time smoothing
            s% gradT_excess_alpha = &
               (1d0 - s% gradT_excess_age_fraction)*alpha + &
               s% gradT_excess_age_fraction*s% gradT_excess_alpha_old
            if (s% gradT_excess_max_change > 0d0) then
               if (s% gradT_excess_alpha > s% gradT_excess_alpha_old) then
                  s% gradT_excess_alpha = min(s% gradT_excess_alpha, s% gradT_excess_alpha_old + &
                     s% gradT_excess_max_change)
               else
                  s% gradT_excess_alpha = max(s% gradT_excess_alpha, s% gradT_excess_alpha_old - &
                     s% gradT_excess_max_change)
               end if
            end if
         else
            s% gradT_excess_alpha = alpha
         end if

         if (s% gradT_excess_alpha < 1d-4) s% gradT_excess_alpha = 0d0
         if (s% gradT_excess_alpha > 0.9999d0) s% gradT_excess_alpha = 1d0

         if (dbg) then
            write(*,1) 'gradT excess new', alpha
            write(*,1) 's% gradT_excess_alpha_old', s% gradT_excess_alpha_old
            write(*,1) 's% gradT_excess_alpha', s% gradT_excess_alpha
            write(*,*)
         end if

      end subroutine set_gradT_excess_alpha


      subroutine check_for_redo_MLT(s, nzlo, nzhi, ierr)
         type (star_info), pointer :: s
         integer, intent(in) :: nzlo, nzhi
         integer, intent(out) :: ierr

         logical :: in_convective_region
         integer :: k, k_bot
         real(dp) :: bot_Hp, bot_r, top_Hp, top_r, dr
         logical :: dbg

         include 'formats'

         ! check_for_redo_MLT assumes that nzlo = 1, nzhi = nz
         ! that is presently true; make sure that assumption doesn't change
         if (.not. ((nzlo.eq.1).and.(nzhi.eq.s%nz))) then
            write(*,*) 'nzlo != 1 or nzhi != nz'
            call mesa_error(__FILE__,__LINE__)
         endif

         ierr = 0
         dbg = .false.

         bot_Hp = 0; bot_r = 0; top_Hp = 0; top_r = 0; dr = 0

         in_convective_region = (s% mlt_mixing_type(nzhi) == convective_mixing)
         k_bot = nzhi
         bot_r = s% r(k_bot)
         bot_Hp = s% scale_height(k_bot)

         do k=nzhi-1, nzlo+1, -1
            if (in_convective_region) then
               if (s% mlt_mixing_type(k) /= convective_mixing) then
                  call end_of_convective_region
               end if
            else ! in non-convective region
               if (s% mlt_mixing_type(k) == convective_mixing) then ! start of a convective region
                  k_bot = k+1
                  in_convective_region = .true.
                  bot_r = s% r(k_bot)
                  bot_Hp = s% scale_height(k_bot)
               end if
            end if
         end do

         if (in_convective_region) then
            k = 1 ! end at top
            call end_of_convective_region
         end if


         contains


         subroutine end_of_convective_region()
            integer :: kk, op_err, mix_type
            real(dp) :: Hp
            logical :: end_dbg

            9 format(a40, 3i7, 99(1pd26.16))
            include 'formats'

            in_convective_region = .false.

            end_dbg = .false.

            top_r = s% r(k)
            top_Hp = s% scale_height(k)
            dr = top_r - bot_r
            Hp = (bot_Hp + top_Hp)/2

            if (dr < s% alpha_mlt(k)*min(top_Hp, bot_Hp) .and. &
                  s% redo_conv_for_dr_lt_mixing_length) then
!$OMP PARALLEL DO PRIVATE(kk,op_err) SCHEDULE(dynamic,2)
               do kk = k, k_bot
                  op_err = 0
                  call redo1_mlt(s,kk,dr,op_err)
                  if (op_err /= 0) ierr = op_err
               end do
!$OMP END PARALLEL DO
            end if

         end subroutine end_of_convective_region


         subroutine redo1_mlt(s,k,dr,ierr)
            type (star_info), pointer :: s
            integer, intent(in) :: k
            real(dp), intent(in) :: dr
            integer, intent(out) :: ierr
            real(dp) :: Hp, reduced_alpha
            include 'formats'
            ierr = 0
            if (dr >= s% mlt_mixing_length(k)) return
            ! if convection zone is smaller than mixing length
            ! redo MLT with reduced alpha so mixing_length = dr
            Hp = s% scale_height(k)
            reduced_alpha = dr/Hp
            call do1_mlt(s, k, reduced_alpha, -1d0, &
               -1d0, -1d0, -1d0, -1d0, -1d0, -1d0, -1d0, &
               ierr)
         end subroutine redo1_mlt


      end subroutine check_for_redo_MLT


      subroutine do1_mlt_eval(s, k, &
            cgrav, m, mstar, r, L, X, &            
            T_face, rho_face, P_face, &
            chiRho_face, chiT_face, &
            Cp_face, opacity_face, grada_face, &            
            alfa, beta, & ! f_face = alfa*f_00 + beta*f_m1
            T_00, T_m1, rho_00, rho_m1, P_00, P_m1, &
            chiRho_for_partials_00, chiT_for_partials_00, &
            chiRho_for_partials_m1, chiT_for_partials_m1, &
            chiRho_00, d_chiRho_00_dlnd, d_chiRho_00_dlnT, &
            chiRho_m1, d_chiRho_m1_dlnd, d_chiRho_m1_dlnT, &
            chiT_00, d_chiT_00_dlnd, d_chiT_00_dlnT, &
            chiT_m1, d_chiT_m1_dlnd, d_chiT_m1_dlnT, &
            Cp_00, d_Cp_00_dlnd, d_Cp_00_dlnT, &
            Cp_m1, d_Cp_m1_dlnd, d_Cp_m1_dlnT, &
            opacity_00, d_opacity_00_dlnd, d_opacity_00_dlnT, &
            opacity_m1, d_opacity_m1_dlnd, d_opacity_m1_dlnT, &
            grada_00, d_grada_00_dlnd, d_grada_00_dlnT, &
            grada_m1, d_grada_m1_dlnd, d_grada_m1_dlnT, &            
            gradr_factor, d_gradr_factor_dw, gradL_composition_term, &
            alpha_semiconvection, semiconvection_option, &
            thermohaline_coeff, thermohaline_option, &
            dominant_iso_for_thermohaline, &
            mixing_length_alpha, alt_scale_height, remove_small_D_limit, &
            MLT_option, Henyey_y_param, Henyey_nu_param, &
            normal_mlt_gradT_factor, &
            prev_conv_vel, max_conv_vel, dt, tau, just_gradr, &
            mixing_type, mlt_basics, mlt_partials1, ierr)

         type (star_info), pointer :: s
         integer, intent(in) :: k
         real(dp), intent(in) :: &
            cgrav, m, mstar, r, L, X, &            
            T_face, rho_face, P_face, &
            chiRho_face, chiT_face, &
            Cp_face, opacity_face, grada_face, &            
            alfa, beta, &
            T_00, T_m1, rho_00, rho_m1, P_00, P_m1, &
            chiRho_for_partials_00, chiT_for_partials_00, &
            chiRho_for_partials_m1, chiT_for_partials_m1, &
            chiRho_00, d_chiRho_00_dlnd, d_chiRho_00_dlnT, &
            chiRho_m1, d_chiRho_m1_dlnd, d_chiRho_m1_dlnT, &
            chiT_00, d_chiT_00_dlnd, d_chiT_00_dlnT, &
            chiT_m1, d_chiT_m1_dlnd, d_chiT_m1_dlnT, &
            Cp_00, d_Cp_00_dlnd, d_Cp_00_dlnT, &
            Cp_m1, d_Cp_m1_dlnd, d_Cp_m1_dlnT, &
            opacity_00, d_opacity_00_dlnd, d_opacity_00_dlnT, &
            opacity_m1, d_opacity_m1_dlnd, d_opacity_m1_dlnT, &
            grada_00, d_grada_00_dlnd, d_grada_00_dlnT, &
            grada_m1, d_grada_m1_dlnd, d_grada_m1_dlnT, &
            gradr_factor, d_gradr_factor_dw, gradL_composition_term, &
            alpha_semiconvection, thermohaline_coeff, mixing_length_alpha, &
            Henyey_y_param, Henyey_nu_param, &
            prev_conv_vel, max_conv_vel, dt, tau, remove_small_D_limit, &
            normal_mlt_gradT_factor
         logical, intent(in) :: alt_scale_height
         character (len=*), intent(in) :: thermohaline_option, MLT_option, semiconvection_option
         integer, intent(in) :: dominant_iso_for_thermohaline
         logical, intent(in) :: just_gradr
         integer, intent(out) :: mixing_type
         real(dp), intent(inout) :: mlt_basics(:) ! (num_mlt_results)
         real(dp), intent(inout), pointer :: mlt_partials1(:) ! =(num_mlt_partials, num_mlt_results)
         integer, intent(out) :: ierr
         
         real(dp), pointer :: mlt_partials(:,:)
         include 'formats'

         if (s% use_other_mlt) then
            call s% other_mlt(  &               
               s% id, k, cgrav, m, mstar, r, L, X, &            
               T_face, rho_face, P_face, &
               chiRho_face, chiT_face, &
               Cp_face, opacity_face, grada_face, &            
               alfa, beta, & ! f_face = alfa*f_00 + beta*f_m1
               T_00, T_m1, rho_00, rho_m1, P_00, P_m1, &
               chiRho_for_partials_00, chiT_for_partials_00, &
               chiRho_for_partials_m1, chiT_for_partials_m1, &
               chiRho_00, d_chiRho_00_dlnd, d_chiRho_00_dlnT, &
               chiRho_m1, d_chiRho_m1_dlnd, d_chiRho_m1_dlnT, &
               chiT_00, d_chiT_00_dlnd, d_chiT_00_dlnT, &
               chiT_m1, d_chiT_m1_dlnd, d_chiT_m1_dlnT, &
               Cp_00, d_Cp_00_dlnd, d_Cp_00_dlnT, &
               Cp_m1, d_Cp_m1_dlnd, d_Cp_m1_dlnT, &
               opacity_00, d_opacity_00_dlnd, d_opacity_00_dlnT, &
               opacity_m1, d_opacity_m1_dlnd, d_opacity_m1_dlnT, &
               grada_00, d_grada_00_dlnd, d_grada_00_dlnT, &
               grada_m1, d_grada_m1_dlnd, d_grada_m1_dlnT, &            
               gradr_factor, d_gradr_factor_dw, gradL_composition_term, &
               alpha_semiconvection, semiconvection_option, &
               thermohaline_coeff, thermohaline_option, &
               dominant_iso_for_thermohaline, &
               mixing_length_alpha, alt_scale_height, remove_small_D_limit, &
               MLT_option, Henyey_y_param, Henyey_nu_param, &
               normal_mlt_gradT_factor, &
               prev_conv_vel, max_conv_vel, dt, tau, just_gradr, &
               mixing_type, mlt_basics, mlt_partials1, ierr)
            return
         end if
         
         mlt_partials(1:num_mlt_partials,1:num_mlt_results) => &
            mlt_partials1(1:num_mlt_partials*num_mlt_results)
         
         ierr = 0
         mlt_basics = 0
         mlt_partials = 0
         call Get_results(s, k, &
            cgrav, m, mstar, r, L, X, &            
            T_face, rho_face, P_face, &
            chiRho_face, chiT_face, &
            Cp_face, opacity_face, grada_face, &            
            alfa, beta, & ! f_face = alfa*f_00 + beta*f_m1
            T_00, T_m1, rho_00, rho_m1, P_00, P_m1, &
            chiRho_for_partials_00, chiT_for_partials_00, &
            chiRho_for_partials_m1, chiT_for_partials_m1, &
            chiRho_00, d_chiRho_00_dlnd, d_chiRho_00_dlnT, &
            chiRho_m1, d_chiRho_m1_dlnd, d_chiRho_m1_dlnT, &
            chiT_00, d_chiT_00_dlnd, d_chiT_00_dlnT, &
            chiT_m1, d_chiT_m1_dlnd, d_chiT_m1_dlnT, &
            Cp_00, d_Cp_00_dlnd, d_Cp_00_dlnT, &
            Cp_m1, d_Cp_m1_dlnd, d_Cp_m1_dlnT, &
            opacity_00, d_opacity_00_dlnd, d_opacity_00_dlnT, &
            opacity_m1, d_opacity_m1_dlnd, d_opacity_m1_dlnT, &
            grada_00, d_grada_00_dlnd, d_grada_00_dlnT, &
            grada_m1, d_grada_m1_dlnd, d_grada_m1_dlnT, &            
            gradr_factor, d_gradr_factor_dw, gradL_composition_term, &
            alpha_semiconvection, semiconvection_option, &
            thermohaline_coeff, thermohaline_option, &
            dominant_iso_for_thermohaline, &
            mixing_length_alpha, alt_scale_height, remove_small_D_limit, &
            MLT_option, Henyey_y_param, Henyey_nu_param, &
            normal_mlt_gradT_factor, &
            prev_conv_vel, max_conv_vel, dt, tau, just_gradr, &
            mixing_type, &
            mlt_basics(mlt_gradT), mlt_partials(:,mlt_gradT), &
            mlt_basics(mlt_gradr), mlt_partials(:,mlt_gradr), &
            mlt_basics(mlt_gradL), mlt_partials(:,mlt_gradL), &
            mlt_basics(mlt_scale_height), mlt_partials(:,mlt_scale_height), &
            mlt_basics(mlt_Lambda), mlt_partials(:,mlt_Lambda), &
            mlt_basics(mlt_convection_velocity), mlt_partials(:,mlt_convection_velocity), &
            mlt_basics(mlt_D), mlt_partials(:,mlt_D), &
            mlt_basics(mlt_D_semi), mlt_partials(:,mlt_D_semi), &
            mlt_basics(mlt_D_thrm), mlt_partials(:,mlt_D_thrm), &
            mlt_basics(mlt_gamma), mlt_partials(:,mlt_gamma), &
            ierr)
         
         if (is_bad(mlt_partials(mlt_cv_var,mlt_gradT))) then
            if (s% report_ierr) &
               write(*,2) 'mlt_partials(mlt_cv_var,mlt_gradT)', k, mlt_partials(mlt_cv_var,mlt_gradT)
            ierr = -1
            if (s% stop_for_bad_nums) stop 'do1_mlt_eval'
         end if
         
      end subroutine do1_mlt_eval


      end module mlt_info