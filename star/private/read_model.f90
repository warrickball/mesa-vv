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

      module read_model

      use star_private_def
      use const_def

      implicit none

      integer, parameter :: bit_for_zams_file = 0
      !integer, parameter ::  = 1 ! UNUSED
      integer, parameter :: bit_for_2models = 2
      integer, parameter :: bit_for_velocity = 3
      integer, parameter :: bit_for_rotation = 4
      integer, parameter :: bit_for_conv_vel = 5 ! saving the data, but not using as variable
      integer, parameter :: bit_for_Eturb = 6
      integer, parameter :: bit_for_RTI = 7
      integer, parameter :: bit_for_constant_L = 8
      integer, parameter :: bit_for_u = 9
      integer, parameter :: bit_for_D_omega = 10
      integer, parameter :: bit_for_am_nu_rot = 11
      integer, parameter :: bit_for_j_rot = 12
      integer, parameter :: bit_for_conv_vel_var = 13
      integer, parameter :: bit_for_D_smooth  = 14
      integer, parameter :: bit_for_RSP = 15
      integer, parameter :: bit_for_no_L_basic_variable = 16

      integer, parameter :: increment_for_unused = 1
      integer, parameter :: increment_for_i_eturb = 1
      integer, parameter :: increment_for_rotation_flag = 1
      integer, parameter :: increment_for_have_j_rot = 1
      integer, parameter :: increment_for_D_omega_flag = 1
      integer, parameter :: increment_for_am_nu_rot_flag = 1
      integer, parameter :: increment_for_RTI_flag = 1
      integer, parameter :: increment_for_D_smooth_flag = 1
      integer, parameter :: increment_for_rsp_flag = 3
      integer, parameter :: increment_for_conv_vel_flag = 1
      integer, parameter :: increment_for_const_L = -1
      integer, parameter :: max_increment = increment_for_unused &
                                          + increment_for_i_eturb &
                                          + increment_for_rotation_flag &
                                          + increment_for_have_j_rot &
                                          + increment_for_D_omega_flag &
                                          + increment_for_am_nu_rot_flag &
                                          + increment_for_RTI_flag &
                                          + increment_for_D_smooth_flag &
                                          + increment_for_rsp_flag &
                                          + increment_for_conv_vel_flag

      integer, parameter :: mesa_zams_file_type = 2**bit_for_zams_file

      character (len=100000) :: buf


      contains


      subroutine finish_load_model(s, restart, want_rsp_model, is_rsp_model, ierr)
         use hydro_vars, only: set_vars
         use star_utils, only: set_m_and_dm, set_dm_bar, total_angular_momentum, reset_epsnuc_vectors, &
            use_xh_to_set_rho_to_dm_div_dV, save_for_d_dt
         use hydro_rotation, only: use_xh_to_update_i_rot_and_j_rot, set_i_rot_from_omega_and_j_rot, &
            use_xh_to_update_i_rot, set_rotation_info
         use rsp, only: rsp_setup_part1, rsp_setup_part2
         use report, only: do_report
         type (star_info), pointer :: s
         logical, intent(in) :: restart, want_rsp_model, is_rsp_model
         integer, intent(out) :: ierr
         integer :: k, i, j, i_u, i_du,  nz
         real(dp) :: u00, um1, xm, total_radiation

         logical, parameter :: dbg = .false.

         include 'formats'

         ierr = 0
         nz = s% nz
         s% brunt_B(1:nz) = 0 ! temporary brunt_B for set_vars

         if (.not. restart) then

            call set_m_and_dm(s)
            call set_dm_bar(s, nz, s% dm, s% dm_bar)
         
            if (s% set_rho_to_dm_div_dV .and. &
                  .not. (s% u_flag .or. s% RSP_flag)) &
               call use_xh_to_set_rho_to_dm_div_dV(s,ierr)
            if (ierr /= 0) then
               write(*,*) &
                  'finish_load_model failed in use_xh_to_set_rho_to_dm_div_dV'
               return
            end if
            
            call reset_epsnuc_vectors(s)

         end if

         if (s% rotation_flag) then
            ! older MESA versions stored only omega in saved models. However, when
            ! using rotation dependent moments of inertia one actually needs to store
            ! the angular momentum in order to initialize the model. This flag is here
            ! to account for the loading of old saved models.
            if (s% have_j_rot) then
               if (restart) then
                  ! only need to compute irot, w_div_w_crit_roche is stored in photos
                  call set_i_rot_from_omega_and_j_rot(s)
               else
                  ! need to set w_div_w_crit_roche as well
                  call use_xh_to_update_i_rot(s)
               end if
            else
               ! need to recompute irot and jrot
               call use_xh_to_update_i_rot_and_j_rot(s)
            end if
            s% total_angular_momentum = total_angular_momentum(s)
            if (s% trace_k > 0 .and. s% trace_k <= nz) then
               do k=1,nz
                  write(*,3) 'lnr', s% model_number, k, s% xh(s% i_lnR, k)
                  write(*,3) 'i_rot', s% model_number, k, s% i_rot(k)
                  write(*,3) 'j_rot', s% model_number, k, s% j_rot(k)
                  write(*,3) 'omega', s% model_number, k, s% omega(k)
               end do
            end if

         end if
         
         if (s% trace_k > 0 .and. s% trace_k <= nz) then
            do j=1,s% species
               write(*,4) 'finish_load_model before set_vars xa(j)', &
                  s% model_number, s% trace_k, j, s% xa(j,s% trace_k)
            end do
         end if

         ! clear some just to avoid getting NaNs at start
         ! e.g., from profile_starting_model
         s% D_mix(1:nz) = 0
         s% adjust_mlt_gradT_fraction(1:nz) = -1
         s% eps_mdot(1:nz) = 0
         s% eps_grav(1:nz) = 0
         s% equL_residual(1:nz) = 0
         s% lnR_residual(1:nz) = 0
         s% lnd_residual(1:nz) = 0
         s% E_residual(1:nz) = 0
         s% u_residual(1:nz) = 0
         s% ergs_error(1:nz) = 0
         if (s% do_element_diffusion) s% edv(:,1:nz) = 0
         if (s% u_flag) then
            s% u_face(1:nz) = 0
            s% P_face(1:nz) = 0
            s% du_dt(1:nz) = 0
         end if

         call save_for_d_dt(s)

         if (dbg) write(*,2) 'load_model: s% dq(1)', 1, s% dq(1)
         if (dbg) write(*,2) 'load_model: s% dm(1)', 1, s% dm(1)
         if (dbg) write(*,2) 'load_model: s% m(1)/msun', 1, s% m(1)/Msun
         
         if (s% rsp_flag) then
            call rsp_setup_part1(s,restart,ierr)
            if (ierr /= 0) then
               write(*,*) 'finish_load_model: rsp_setup_part1 returned ierr', ierr
               return
            end if
         end if
         
         s% doing_finish_load_model = .true.         
         call set_vars(s, s% dt, ierr)
         if (ierr /= 0) then
            write(*,*) 'finish_load_model: failed in set_vars'
            return
         end if
         s% doing_finish_load_model = .false.
         
         if (s% rsp_flag) then
            call rsp_setup_part2(s, restart, want_rsp_model, is_rsp_model, ierr)
            if (ierr /= 0) then
               write(*,*) 'finish_load_model: rsp_setup_part2 returned ierr', ierr
               return
            end if
         end if
         
         if (dbg) write(*,2) 'load_model: s% dq(1)', 1, s% dq(1)
         if (dbg) write(*,2) 'load_model: s% dm(1)', 1, s% dm(1)
         if (dbg) write(*,2) 'load_model: s% m(1)/msun', 1, s% m(1)/Msun

         if (s% trace_k > 0 .and. s% trace_k <= nz) then
            do j=1,s% species
               write(*,4) 'finish_load_model after set_vars xa(j)', &
                  s% model_number, s% trace_k, j, s% xa(j,s% trace_k)
            end do
         end if

         ! actual brunt_B is set as part of do_report
         s% doing_finish_load_model = .true.
         call do_report(s, ierr)
         s% doing_finish_load_model = .false.
         if (ierr /= 0) then
            write(*,*) 'finish_load_model: failed in do_report'
            return
         end if

         if (s% rotation_flag) then
            ! this ensures fp, ft, r_equatorial and r_polar are set by the end
            call set_rotation_info(s, .true., ierr)
            if (ierr /= 0) then
               write(*,*) &
                  'finish_load_model failed in set_rotation_info'
               return
            end if
         end if

      end subroutine finish_load_model


      subroutine read1_model( &
            s, species, nvar_hydro, nz, iounit, &
            is_RSP_model, want_RSP_model, &
            xh, xa, q, dq, D_smooth, omega, j_rot, D_omega, am_nu_rot, &
            lnT, conv_vel, perm, ierr)
         use star_utils, only: set_qs
         use chem_def
         type (star_info), pointer :: s
         integer, intent(in) :: species, nvar_hydro, nz, iounit, perm(:)
         logical, intent(in) :: is_RSP_model, want_RSP_model
         real(dp), dimension(:,:), intent(out) :: xh, xa
         real(dp), dimension(:), intent(out) :: &
            q, dq, D_smooth, omega, j_rot, D_omega, am_nu_rot, lnT, conv_vel
         integer, intent(out) :: ierr

         integer :: i, j, k, n, i_lnd, i_lnT, i_lnR, i_lum, i_eturb, i_eturb_RSP, &
            i_erad_RSP, i_Fr_RSP, i_v, i_u, i_alpha_RTI, i_ln_cvpv0, ii
         real(dp), target :: vec_ary(species + nvar_hydro + max_increment)
         real(dp), pointer :: vec(:)
         real(dp) :: r00, rm1
         integer :: nvec
         logical :: no_L

         include 'formats'

         ierr = 0
         vec => vec_ary

         i_lnd = s% i_lnd
         i_lnT = s% i_lnT
         i_lnR = s% i_lnR
         i_lum = s% i_lum
         no_L = (i_lum == 0)
         i_eturb = s% i_eturb
         i_v = s% i_v
         i_u = s% i_u
         i_alpha_RTI = s% i_alpha_RTI
         i_eturb_RSP = s% i_eturb_RSP
         i_erad_RSP = s% i_erad_RSP
         i_Fr_RSP = s% i_Fr_RSP
         i_ln_cvpv0 = s% i_ln_cvpv0
         n = species + nvar_hydro + 1 ! + 1 is for dq
         if (i_eturb /= 0) n = n+increment_for_i_eturb ! read eturb
         if (s% rotation_flag) n = n+increment_for_rotation_flag ! read omega
         if (s% have_j_rot) n = n+increment_for_have_j_rot ! read j_rot
         if (s% D_omega_flag) n = n+increment_for_D_omega_flag ! read D_omega
         if (s% am_nu_rot_flag) n = n+increment_for_am_nu_rot_flag ! read am_nu_rot
         if (s% RTI_flag) n = n+increment_for_RTI_flag ! read alpha_RTI
         if (is_RSP_model) n = n+increment_for_rsp_flag ! read eturb, erad, Fr
         if (s% D_smooth_flag) n = n+increment_for_D_smooth_flag ! read D_smooth
         if (s% conv_vel_flag .or. s% have_previous_conv_vel) n = n+increment_for_conv_vel_flag ! read conv_vel
         if (s% constant_L) n = n+increment_for_const_L ! do not read L
         if (is_RSP_model .and. .not. want_RSP_model) then
            if (.not. s% Eturb_flag) then
               write(*,*) '(is_RSP_model .and. .not. want_RSP_model) requires Eturb_flag true'
               ierr = -1
               return
            end if
         end if

!$omp critical (read1_model_loop)
! make this a critical section to so don't have to dynamically allocate buf
         do i = 1, nz
            read(iounit,'(a)',iostat=ierr) buf
            if (ierr /= 0) then
               write(*,3) 'read failed i', i, nz
               exit
            end if
            call str_to_vector(buf, vec, nvec, ierr)
            if (ierr /= 0) then
               write(*,*) 'str_to_vector failed'
               write(*,'(a,i8,1x,a)') 'buf', i, trim(buf)
               exit
            end if
            j = int(vec(1))
            if (j /= i) then
               ierr = -1
               write(*, *) 'error in reading model data   j /= i'
               write(*, *) 'species', species
               write(*, *) 'j', j
               write(*, *) 'i', i
               exit
            end if
            j = 1
            j=j+1; if (i_lnd /= 0) xh(i_lnd,i) = vec(j)
            j=j+1
            if (i_lnT /= 0) then
               xh(i_lnT,i) = vec(j)
            else
               lnT(i) = vec(j)
            end if
            j=j+1; xh(i_lnR,i) = vec(j)            
            if (is_RSP_model) then
               if (want_RSP_model) then
                  j=j+1; xh(i_eturb_RSP,i) = vec(j)
                  j=j+1; xh(i_erad_RSP,i) = vec(j)
                  j=j+1; xh(i_Fr_RSP,i) = vec(j)
                  j=j+1; s% L(i) = vec(j)
               else ! convert from RSP to Eturb form
                  j=j+1; xh(i_eturb,i) = max(min_eturb,vec(j))
                  j=j+1; !xh(i_erad,i) = vec(j)
                  j=j+1; !xh(i_Fr,i) = vec(j)
                  j=j+1; s% L(i) = vec(j)
               end if
            end if            
            if (i_eturb /= 0) then
               j=j+1; xh(i_eturb,i) = max(min_eturb,vec(j))
            end if            
            if (.not. (s% constant_L .or. no_L)) then
               j=j+1; xh(i_lum,i) = vec(j)
            end if            
            j=j+1; dq(i) = vec(j)
            if (i_v /= 0) then
               j=j+1; xh(i_v,i) = vec(j)
            end if
            if (s% rotation_flag) then
               j=j+1; omega(i) = vec(j)
            end if
            if (s% have_j_rot) then
               !NOTE: MESA version 10108 was first to store j_rot in saved files
               j=j+1; j_rot(i) = vec(j)
            end if
            if (s% D_omega_flag) then
               j=j+1; D_omega(i) = vec(j)
            end if
            if (s% am_nu_rot_flag) then
               j=j+1; am_nu_rot(i) = vec(j)
            end if
            if (i_u /= 0) then
               j=j+1; xh(i_u,i) = vec(j)
            end if
            if (s% RTI_flag) then
               j=j+1; xh(i_alpha_RTI,i) = vec(j)
            end if
            if (s% D_smooth_flag) then
               j=j+1; D_smooth(i) = vec(j)
            end if
            if (s% conv_vel_flag .or. s% have_previous_conv_vel) then
               j=j+1
               if (s% conv_vel_flag) then
                  xh(i_ln_cvpv0,i) = log(vec(j)+s% conv_vel_v0)
               else
                  conv_vel(i) = vec(j)
               end if
            end if
            if (j+species > nvec) then
               ierr = -1
               write(*, *) 'error in reading model data  j+species > nvec'
               write(*, *) 'j+species', j+species
               write(*, *) 'nvec', nvec
               write(*, *) 'j', j
               write(*, *) 'species', species
               exit
            end if
            do ii=1,species
               xa(perm(ii),i) = vec(j+ii)
            end do
         end do
!$omp end critical (read1_model_loop)

         if (ierr /= 0) then
            write(*,*) 'read1_model_loop failed'
            return
         end if
         
         if (.not. s% D_smooth_flag) D_smooth(1:nz) = 0d0
         
         if (s% rotation_flag .and. .not. s% D_omega_flag) &
            s% D_omega(1:nz) = 0d0
         
         if (s% rotation_flag .and. .not. s% am_nu_rot_flag) &
            s% am_nu_rot(1:nz) = 0d0

         if (s% constant_L) xh(i_lum,1:nz) = s% L_center

         if (i_lum /= 0) then
            s% prev_Lmax = maxval(abs(xh(i_lum,1:nz)))
         else
            s% prev_Lmax = s% L_center
         end if
         
         if (want_RSP_model .and. .not. is_RSP_model) then
            ! proper values for these will be set in rsp_setup_part2
            s% xh(i_eturb_RSP,1:nz) = 0d0 
            s% xh(i_erad_RSP,1:nz) = 0d0 
            s% xh(i_Fr_RSP,1:nz) = 0d0 
         end if

         call set_qs(nz, q, dq, ierr)
         if (ierr /= 0) then
            write(*,*) 'set_qs failed in read1_model sum(dq)', sum(dq(1:nz))
            return
         end if

      end subroutine read1_model


      subroutine do_read_saved_model(s, filename, want_RSP_model, is_RSP_model, ierr)
         use utils_lib
         use utils_def
         use chem_def
         use net, only: set_net
         use alloc, only: set_var_info, &
            free_star_info_arrays, allocate_star_info_arrays, set_chem_names
         use star_utils, only: yrs_for_init_timestep, set_phase_of_evolution
         type (star_info), pointer :: s
         character (len=*), intent(in) :: filename
         logical, intent(in) :: want_RSP_model
         logical, intent(out) :: is_RSP_model
         integer, intent(out) :: ierr

         integer :: iounit, n, i, t, file_type, &
            year_month_day_when_created, nz, species, nvar, count
         logical :: do_read_prev, no_L
         real(dp) :: initial_mass, initial_z, initial_y, &
            tau_factor, fixed_L_for_BB_outer_BC, &
            Tsurf_factor, opacity_factor, mixing_length_alpha
         character (len=strlen) :: buffer, string, message
         character (len=net_name_len) :: net_name
         character(len=iso_name_length), pointer :: names(:) ! (species)
         integer, pointer :: perm(:) ! (species)

         include 'formats'

         ierr = 0
         open(newunit=iounit, file=trim(filename), status='old', action='read', iostat=ierr)
         if (ierr /= 0) then
            write(*,*) 'open failed', ierr, iounit
            write(*, '(a)') 'failed to open ' // trim(filename)
            return
         end if

         ! use token to get file_type so can have comments at start of file
         n = 0
         i = 0
         t = token(iounit, n, i, buffer, string)
         if (t == eof_token) then
            write(*, '(a)') 'failed to find file type at start of ' // trim(filename)
            return
         end if
         if (t /= name_token) then
            write(*, '(a)') 'failed to find file type at start of ' // trim(filename)
            return
         end if
         read(string,fmt=*,iostat=ierr) file_type
         if (ierr /= 0) then
            write(*, '(a)') 'failed to find file type at start of ' // trim(filename)
            return
         end if

         read(iounit, *, iostat=ierr) ! skip the blank line after the file type
         if (ierr /= 0) then
            return
         end if

         s% model_number = 0
         s% star_age = 0
         s% xmstar = -1
         
         fixed_L_for_BB_outer_BC = s% fixed_L_for_BB_outer_BC
         tau_factor = s% tau_factor
         Tsurf_factor = s% Tsurf_factor
         mixing_length_alpha = s% mixing_length_alpha
         opacity_factor = s% opacity_factor

         call read_properties(iounit, &
            net_name, species, nz, year_month_day_when_created, &
            initial_mass, initial_z, initial_y, mixing_length_alpha, &
            s% model_number, s% star_age, tau_factor, &
            fixed_L_for_BB_outer_BC, Tsurf_factor, opacity_factor, &
            s% xmstar, s% R_center, s% L_center, s% v_center, &
            s% cumulative_energy_error, s% num_retries, ierr)

         if (ierr /= 0 .or. initial_mass < 0 .or. nz < 0 &
               .or. initial_z < 0 .or. species < 0 .or. &
               is_bad(initial_mass + initial_z)) then
            ierr = -1
            write(*, *) 'do_read_model: missing required properties'
            write(*,*) 'initial_mass', initial_mass
            write(*,*) 'initial_z', initial_z
            write(*,*) 'nz', nz
            write(*,*) 'species', species
            return
         end if
         
         s% init_model_number = s% model_number

         s% time = s% star_age*secyer

         if (abs(tau_factor - s% tau_factor) > tau_factor*1d-9 .and. &
               s% tau_factor /= s% job% set_to_this_tau_factor) then
            ! don't change if just set by inlist
            write(*,*)
            write(*,1) 'WARNING: changing to saved tau_factor =', tau_factor
            write(*,*)
            s% tau_factor = tau_factor
            s% force_tau_factor = tau_factor
         end if

         if (abs(fixed_L_for_BB_outer_BC - s% fixed_L_for_BB_outer_BC) > &
                  fixed_L_for_BB_outer_BC*1d-9) then
            write(*,*)
            write(*,1) 'WARNING: changing to saved fixed_L_for_BB_outer_BC =', fixed_L_for_BB_outer_BC
            write(*,*)
            s% fixed_L_for_BB_outer_BC = fixed_L_for_BB_outer_BC
         end if

         if (abs(Tsurf_factor - s% Tsurf_factor) > Tsurf_factor*1d-9 .and. &
               s% Tsurf_factor /= s% job% set_to_this_Tsurf_factor) then
            ! don't change if just set by inlist
            write(*,*)
            write(*,1) 'WARNING: changing to saved Tsurf_factor =', Tsurf_factor
            write(*,*)
            s% Tsurf_factor = Tsurf_factor
            s% force_Tsurf_factor = Tsurf_factor
         end if

         if (abs(opacity_factor - s% opacity_factor) > opacity_factor*1d-9 .and. &
               s% opacity_factor /= s% job% relax_to_this_opacity_factor) then
            ! don't change if just set by inlist
            write(*,*)
            write(*,1) 'WARNING: changing to saved opacity_factor =', opacity_factor
            write(*,*)
            s% opacity_factor = opacity_factor
            s% force_opacity_factor = opacity_factor
         end if

         if (abs(mixing_length_alpha - s% mixing_length_alpha) > mixing_length_alpha*1d-9) then
            write(*,*)
            write(*,1) 'WARNING: model saved with mixing_length_alpha =', mixing_length_alpha
            write(*,1) 'but current setting for mixing_length_alpha =', s% mixing_length_alpha
            write(*,*)
         end if

         s% net_name = trim(net_name)
         s% species = species
         s% Eturb_flag = BTEST(file_type, bit_for_Eturb)
         s% v_flag = BTEST(file_type, bit_for_velocity)
         s% u_flag = BTEST(file_type, bit_for_u)
         s% rotation_flag = BTEST(file_type, bit_for_rotation)
         s% have_j_rot = BTEST(file_type, bit_for_j_rot)
         s% D_omega_flag = BTEST(file_type, bit_for_D_omega)
         s% am_nu_rot_flag = BTEST(file_type, bit_for_am_nu_rot)
         s% RTI_flag = BTEST(file_type, bit_for_RTI)
         s% constant_L = BTEST(file_type, bit_for_constant_L)
         s% conv_vel_flag = BTEST(file_type, bit_for_conv_vel_var)
         s% D_smooth_flag = BTEST(file_type, bit_for_D_smooth)
         is_RSP_model = BTEST(file_type, bit_for_RSP)
         no_L = BTEST(file_type, bit_for_no_L_basic_variable)
         
         s% rsp_flag = is_RSP_model .and. want_RSP_model
         
         if (want_RSP_model .and. .not. is_RSP_model) then
            write(*,*)
            write(*,*) 'automatically converting ' // trim(filename) // ' to RSP form'
            write(*,*)
            s% rsp_flag = .true.
         end if
         
         if (is_RSP_model .and. .not. want_RSP_model) then
            write(*,*)
            write(*,*) 'automatically converting ' // trim(filename) // ' from RSP to Eturb form'
            write(*,*)
            s% Eturb_flag = .true.
         end if
         
         if (no_L .and. s% i_lum /= 0) then
            write(*,*)
            write(*,*) trim(filename) // ' has no L variables, but need them.'
            write(*,*)
            ierr = -1
            return
         end if

         s% have_previous_conv_vel = BTEST(file_type, bit_for_conv_vel)
         s% initial_z = initial_z

         s% mstar = initial_mass*Msun
         if (s% xmstar < 0) then
            s% M_center = 0
            s% xmstar = s% mstar
         else
            s% M_center = s% mstar - s% xmstar
         end if
         if (is_bad(s% M_center)) then
            write(*,1) 'M_center mstar xmstar initial_mass', &
               s% M_center, s% mstar, s% xmstar, initial_mass
            stop 'do_read_saved_model'
         end if

         call set_net(s, s% net_name, ierr)
         if (ierr /= 0) then
            write(*,*) &
               'do_read_saved_model failed in set_net for net_name = ' // trim(s% net_name)
            return
         end if
         
         call set_var_info(s, ierr)
         if (ierr /= 0) then
            write(*,*) 'do_read_saved_model failed in set_var_info'
            return
         end if

         ! fixup chem names now that have nvar_hydro
         call set_chem_names(s)

         s% nz = nz
         call free_star_info_arrays(s)
         call allocate_star_info_arrays(s, ierr)
         if (ierr /= 0) then
            write(*,*) 'do_read_saved_model failed in allocate_star_info_arrays'
            return
         end if

         allocate(names(species), perm(species))
         call get_chem_col_names(s, iounit, species, names, perm, ierr)
         if (ierr /= 0) then
            deallocate(names, perm)
            write(*,*) 'do_read_saved_model failed in get_chem_col_names'
            return
         end if

         count = 0
         do i=1,species
            if (perm(i)==0) then
               count = count+1
               write(*,*) "Mod file has isotope ",trim(names(i)), " but that is not in the net"
            end if
         end do 
         if (count/=0) call mesa_error(__FILE__,__LINE__)


         nvar = s% nvar
         call read1_model( &
               s, s% species, s% nvar_hydro, nz, iounit, &
               is_RSP_model, want_RSP_model, &
               s% xh, s% xa, s% q, s% dq, s% D_smooth, &
               s% omega, s% j_rot, s% D_omega, s% am_nu_rot, s% lnT, &
               s% prev_conv_vel_from_file, perm, ierr)
         deallocate(names, perm)
         if (ierr /= 0) then
            write(*,*) 'do_read_saved_model failed in read1_model'
            return
         end if
         
         s% use_previous_conv_vel_from_file = s% have_previous_conv_vel

         do_read_prev = BTEST(file_type, bit_for_2models)
         if (ierr == 0) then
            if (do_read_prev) then
               call read_prev
            else
               s% generations = 1
            end if
         end if

         close(iounit)


         contains


         subroutine read_prev
            integer :: k

            do k=1, 3
               read(iounit, *, iostat=ierr)
               if (ierr /= 0) return
            end do
            call read_prev_properties
            if (ierr /= 0) return

            ! we do read_prev_properties to set initial timestep,
            ! but we don't use the previous model
            ! because we need to have other info about that isn't saved
            ! such as conv_vel and mixing_type

            s% generations = 1

         end subroutine read_prev


         subroutine read_prev_properties
            character (len=132) :: line
            real(dp) :: tmp, skip_val
            integer :: i
            include 'formats'
            
            ierr = 0
            s% dt = -1
            s% mstar_old = -1
            s% dt_next = -1
            s% nz_old = -1

            do ! until reach a blank line
               read(iounit, fmt='(a)', iostat=ierr) line
               if (ierr /= 0) return

               if (len_trim(line) == 0) exit ! blank line

               if (match_keyword('previous n_shells', line, tmp)) then
                  s% nz_old = int(tmp)
                  cycle
               end if

               if (match_keyword('timestep (seconds)', line, s% dt)) then
                  cycle
               end if

               if (match_keyword('previous mass (grams)', line, s% mstar_old)) then
                  cycle
               end if

               if (match_keyword('dt_next (seconds)', line, s% dt_next)) then
                  cycle
               end if

               if (match_keyword('year_month_day_when_created', line, skip_val)) cycle

            end do
            if (s% dt < 0) then
               ierr = -1
               write(*, *) 'missing dt for previous model'
            end if
            if (s% mstar_old < 0) then
               ierr = -1
               write(*, *) 'missing mstar_old for previous model'
            end if
            if (s% dt_next < 0) then
               ierr = -1
               write(*, *) 'missing dt_next for previous model'
            end if

         end subroutine read_prev_properties


      end subroutine do_read_saved_model


      subroutine do_read_saved_model_number(fname, model_number, ierr)
         character (len=*), intent(in) :: fname
         integer, intent(inout) :: model_number
         integer, intent(out) :: ierr
         character (len=strlen) :: net_name
         integer :: species, n_shells, &
            num_retries, year_month_day_when_created
         real(dp) :: m_div_msun, initial_z, &
            mixing_length_alpha, star_age, fixed_L_for_BB_outer_BC, &
            tau_factor, Tsurf_factor, opacity_factor, &
            xmstar, R_center, L_center, v_center, cumulative_energy_error
         call do_read_saved_model_properties(fname, &
            net_name, species, n_shells, year_month_day_when_created, &
            m_div_msun, initial_z, mixing_length_alpha, &
            model_number, star_age, tau_factor, &
            fixed_L_for_BB_outer_BC, Tsurf_factor, opacity_factor, &
            xmstar, R_center, L_center, v_center, &
            cumulative_energy_error, num_retries, ierr)
      end subroutine do_read_saved_model_number


      subroutine do_read_saved_model_age(fname, star_age, ierr)
         character (len=*), intent(in) :: fname
         real(dp), intent(inout) :: star_age
         integer, intent(out) :: ierr
         character (len=strlen) :: net_name
         integer :: species, n_shells, model_number, &
            num_retries, year_month_day_when_created
         real(dp) :: m_div_msun, initial_z, &
            mixing_length_alpha, cumulative_energy_error, &
            tau_factor, Tsurf_factor, &
            fixed_L_for_BB_outer_BC, opacity_factor, &
            xmstar, R_center, L_center, v_center
         call do_read_saved_model_properties(fname, &
            net_name, species, n_shells, year_month_day_when_created, &
            m_div_msun, initial_z, mixing_length_alpha, &
            model_number, star_age, tau_factor, &
            fixed_L_for_BB_outer_BC, Tsurf_factor, opacity_factor, &
            xmstar, R_center, L_center, v_center, &
            cumulative_energy_error, num_retries, ierr)
      end subroutine do_read_saved_model_age


      subroutine do_read_saved_model_properties(fname, &
            net_name, species, n_shells, year_month_day_when_created, &
            m_div_msun, initial_z, mixing_length_alpha, &
            model_number, star_age, tau_factor, &
            fixed_L_for_BB_outer_BC, Tsurf_factor, opacity_factor, &
            xmstar, R_center, L_center, v_center, &
            cumulative_energy_error, num_retries, ierr)
         use utils_lib
         character (len=*), intent(in) :: fname
         character (len=*), intent(inout) :: net_name
         integer, intent(inout) :: species, n_shells, &
            year_month_day_when_created, num_retries, model_number
         real(dp), intent(inout) :: m_div_msun, initial_z, &
            mixing_length_alpha, star_age, tau_factor, &
            fixed_L_for_BB_outer_BC, Tsurf_factor, opacity_factor, &
            xmstar, R_center, L_center, v_center, cumulative_energy_error
         integer, intent(out) :: ierr
         integer :: iounit
         real(dp) :: initial_y
         ierr = 0
         open(newunit=iounit, file=trim(fname), action='read', status='old', iostat=ierr)
         if (ierr /= 0) then
            write(*, *) 'failed to open ' // trim(fname)
            return
         end if
         read(iounit, *, iostat=ierr)
         if (ierr /= 0) then
            close(iounit)
            return
         end if
         read(iounit, *, iostat=ierr)
         if (ierr /= 0) then
            close(iounit)
            return
         end if
         call read_properties(iounit, &
            net_name, species, n_shells, year_month_day_when_created, &
            m_div_msun, initial_z, initial_y, mixing_length_alpha, &
            model_number, star_age, tau_factor, &
            fixed_L_for_BB_outer_BC, Tsurf_factor, opacity_factor, &
            xmstar, R_center, L_center, v_center, &
            cumulative_energy_error, num_retries, ierr)
         close(iounit)
      end subroutine do_read_saved_model_properties


      subroutine read_properties(iounit, &
            net_name, species, n_shells, year_month_day_when_created, &
            m_div_msun, initial_z, initial_y, mixing_length_alpha, &
            model_number, star_age, tau_factor, &
            fixed_L_for_BB_outer_BC, Tsurf_factor, opacity_factor, &
            xmstar, R_center, L_center, v_center, &
            cumulative_energy_error, num_retries, ierr)
         integer, intent(in) :: iounit
         character (len=*), intent(inout) :: net_name
         integer, intent(inout) :: species, n_shells, &
            year_month_day_when_created, model_number, num_retries
         real(dp), intent(inout) :: m_div_msun, initial_z, initial_y, &
            mixing_length_alpha, star_age, tau_factor, &
            fixed_L_for_BB_outer_BC, Tsurf_factor, opacity_factor, &
            xmstar, R_center, L_center, v_center, cumulative_energy_error
         integer, intent(out) :: ierr
         character (len=132) :: line
         real(dp) :: tmp
         ierr = 0
         do ! until reach a blank line
            read(iounit, fmt='(a)', iostat=ierr) line
            if (ierr /= 0) return
            if (len_trim(line) == 0) return ! blank line
            if (match_keyword_for_string('net_name', line, net_name)) then; cycle; end if
            if (match_keyword('species', line, tmp)) then; species = int(tmp); cycle; end if
            if (match_keyword('n_shells', line, tmp)) then; n_shells = int(tmp); cycle; end if
            if (match_keyword('model_number', line, tmp)) then; model_number = int(tmp); cycle; end if
            if (match_keyword('M/Msun', line, m_div_msun)) cycle
            if (match_keyword('star_age', line, star_age)) cycle
            if (match_keyword('initial_z', line, initial_z)) cycle
            if (match_keyword('initial_y', line, initial_y)) cycle
            if (match_keyword('mixing_length_alpha', line, mixing_length_alpha)) cycle
            if (match_keyword('tau_factor', line, tau_factor)) cycle
            if (match_keyword('fixed_L_for_BB_outer_BC', line, fixed_L_for_BB_outer_BC)) cycle
            if (match_keyword('Tsurf_factor', line, Tsurf_factor)) cycle
            if (match_keyword('opacity_factor', line, opacity_factor)) cycle
            if (match_keyword('xmstar', line, xmstar)) cycle
            if (match_keyword('R_center', line, R_center)) cycle
            if (match_keyword('L_center', line, L_center)) cycle
            if (match_keyword('v_center', line, v_center)) cycle
            if (match_keyword('cumulative_energy_error', line, cumulative_energy_error)) cycle
            if (match_keyword('year_month_day_when_created', line, tmp)) then
               year_month_day_when_created = int(tmp); cycle; end if
            if (match_keyword('tau_photosphere', line, tmp)) cycle
            if (match_keyword('num_retries', line, tmp)) then; num_retries = int(tmp); cycle; end if
         end do
      end subroutine read_properties


      logical function match_keyword(key, txt, value)
         ! returns true if leading non-blank part of txt is same as key.
         ! i.e., skips leading blanks in txt before testing equality.
         character (len=*), intent(in) :: key, txt
         real(dp), intent(inout) :: value
         integer :: i, j, k, ierr
         i = len(key)
         k = len(txt)
         j = 1
         do while (j <= k .and. txt(j:j) == ' ')
            j = j+1
         end do
         match_keyword = (txt(j:j+i-1) == key)
         ierr = 0
         if (match_keyword) then
            read(txt(j+i:k), fmt=*, iostat=ierr) value
            if (ierr /= 0) match_keyword = .false.
         end if
      end function match_keyword


      logical function match_keyword_for_string(key, txt, value)
         ! returns true if leading non-blank part of txt is same as key.
         ! i.e., skips leading blanks in txt before testing equality.
         character (len=*), intent(in) :: key, txt
         character (len=*), intent(inout) :: value
         integer :: i, j, k, str_len
         logical, parameter :: dbg = .false.
         i = len(key)
         k = len(txt)
         j = 1
         do while (j <= k .and. txt(j:j) == ' ')
            j = j+1
         end do
         match_keyword_for_string = (txt(j:j+i-1) == key)
         if (.not. match_keyword_for_string) return
         if (dbg) then
            write(*,*) 'matching ' // trim(key)
            write(*,*) 'txt ' // trim(txt)
         end if
         j = j+i
         do while (j <= k .and. txt(j:j) == ' ')
            j = j+1
         end do
         if (j > k) then
            match_keyword_for_string = .false.
            if (dbg) write(*,*) 'j > k'
            return
         end if
         if (txt(j:j) /= '''') then
            match_keyword_for_string = .false.
            if (dbg) write(*,*) 'no leading quote'
            return
         end if
         j = j+1
         i = 1
         str_len = len(value)
         do while (j <= k .and. txt(j:j) /= '''')
            value(i:i) = txt(j:j)
            i = i+1
            j = j+1
         end do
         do while (i <= str_len)
            value(i:i) = ' '
            i = i+1
         end do
         if (dbg) write(*,*) 'value <' // trim(value) // ">"
      end function match_keyword_for_string


      subroutine get_chem_col_names(s, iounit, species, names, perm, ierr)
         use chem_def, only: iso_name_length
         use chem_lib, only: chem_get_iso_id
         type (star_info), pointer :: s
         integer, intent(in) :: iounit, species
         character(len=iso_name_length), intent(out) :: names(species)
         integer, intent(out) :: perm(species)
         integer, intent(out) :: ierr

         character (len=50000) :: buffer
         character (len=20) :: string
         integer :: n, i, j1, j2, str_len, l, indx, j, num_found

         ierr = 0
         read(iounit,fmt='(a)',iostat=ierr) buffer
         if (ierr /= 0) return

         n = len_trim(buffer)
         i = 0
         num_found = 0
       token_loop: do ! have non-empty buffer
            i = i+1
            if (i > n) then
               write(*,*) 'get_chem_col_names: failed to find all of the names'
               ierr = -1
               return
            end if
            if (buffer(i:i) == char(9)) cycle token_loop ! skip tabs
            select case(buffer(i:i))
               case (' ')
                  cycle token_loop ! skip spaces
               case default
                  j1 = i; j2 = i
                  name_loop: do
                     if (i+1 > n) exit
                     if (buffer(i+1:i+1) == ' ') exit
                     if (buffer(i+1:i+1) == '(') exit
                     if (buffer(i+1:i+1) == ')') exit
                     if (buffer(i+1:i+1) == ',') exit
                     i = i+1
                     j2 = i
                  end do name_loop
                  str_len = len(string)
                  l = j2-j1+1
                  if (l > str_len) then
                     l = str_len
                     j2 = l+j1-1
                  end if
                  string(1:l) = buffer(j1:j2)
                  do j = l+1, str_len
                     string(j:j) = ' '
                  end do

                  indx = chem_get_iso_id(string)

                  if (indx > 0) then
                     num_found = num_found+1
                     names(num_found) = trim(string)
                     perm(num_found) = s% net_iso(indx)
                     !write(*,*) trim(string), num_found, perm(num_found)
                     if (num_found == species) return
                  end if

            end select
         end do token_loop

      end subroutine get_chem_col_names


      end module read_model