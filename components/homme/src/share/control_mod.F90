#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

! This module contains constants and namelist variables used through out the model
! to avoid circular dependancies please do not 'use' any further modules here.
!
module control_mod
  use kinds, only : real_kind
  use physical_constants, only: dd_pi

  integer, public, parameter :: MAX_STRING_LEN=240
  integer, public, parameter :: MAX_FILE_LEN=240
  character(len=MAX_STRING_LEN)    , public :: integration    ! time integration (explicit, or full imp)

  ! Tracer transport algorithm type:
  !     0  spectral-element Eulerian
  !    12 interpolation semi-Lagrangian
  integer, public  :: transport_alg = 0
  ! Constrained density reconstructor for SL property preservation; not used if
  ! transport_alg = 0:
  !     0  none
  !     2  QLT
  !     3  CAAS
  !    20  QLT  with superlevels
  !    30  CAAS with superlevels
  integer, public  :: semi_lagrange_cdr_alg = 20
  ! If true, check mass conservation and shape preservation. The second
  ! implicitly checks tracer consistency.
  logical, public  :: semi_lagrange_cdr_check = .false.
  ! If > 0 and nu_q > 0, apply hyperviscosity to tracers 1 through this value,
  ! rather than just those that couple to the dynamics at the dynamical time
  ! step. These latter are 'active' tracers, in contrast to 'passive' tracers
  ! that directly couple only to the physics.
  integer, public  :: semi_lagrange_hv_q = 0
  ! If >= 1, then the SL algorithm may choose a nearby point inside the element
  ! halo available to it if the actual point is outside the halo. This is done
  ! in levels <= this parameter.
  integer, public :: semi_lagrange_nearest_point_lev = 0

! flag used by preqx, theta-l and theta-c models
! should be renamed to "hydrostatic_mode"
  logical, public :: theta_hydrostatic_mode


  integer, public  :: tstep_type= 5                           ! preqx timestepping options
  integer, public  :: rk_stage_user  = 0                      ! number of RK stages (shallow water model) 
  integer, public  :: ftype = 0                                ! Forcing Type
                                                               ! ftype = 0  HOMME ApplyColumn() type forcing process split
                                                               ! ftype = -1   ignore forcing  (used for testing energy balance)
                                              
  integer, public :: qsplit = 1           ! ratio of dynamics tsteps to tracer tsteps
  integer, public :: rsplit = 0           ! for vertically lagrangian dynamics, apply remap
                                          ! every rsplit tracer timesteps
  integer, public :: LFTfreq=0            ! leapfrog-trapazoidal frequency (shallow water only)
                                          ! interspace a lf-trapazoidal step every LFTfreq leapfrogs    
                                          ! 0 = disabled

! vert_remap_q_alg:   -1  remap without monotone filter, used for some test cases
!                      0  default value, Zerroukat monotonic splines
!                      1  PPM vertical remap with mirroring at the boundaries
!                         (solid wall bc's, high-order throughout)
!                      2  PPM vertical remap without mirroring at the boundaries
!                         (no bc's enforced, first-order at two cells bordering top and bottom boundaries)
 integer, public :: vert_remap_q_alg = 0

! advect theta 0: conservation form 
!              1: expanded divergence form (less noisy, non-conservative)
 integer, public :: theta_advect_form = 0

 integer, public :: cubed_sphere_map = -1  ! -1 = chosen at run time
                                           !  0 = equi-angle Gnomonic (default)
                                           !  1 = equi-spaced Gnomonic (not yet coded)
                                           !  2 = element-local projection  (for var-res)
                                           !  3 = parametric (not yet coded)

!tolerance to define smth small, was introduced for lim 8 in 2d and 3d
  real (kind=real_kind), public, parameter :: tol_limiter=1e-13

  integer              , public :: limiter_option = 0
  character(len=MAX_STRING_LEN)    , public :: precon_method  ! if semi_implicit, type of preconditioner:
                                                  ! choices block_jacobi or identity

  integer              , public :: coord_transform_method   ! If zoltan2 is used, various ways of representing the coordinates methods
                                                            ! Instead of using the sphere coordinates, it is better to use cube or projected 2D coordinates for quality.
                                                            ! check params_mod for options.

  integer              , public :: z2_map_method            ! If zoltan2 is used,
                                                            ! Task mapping method to be used by zoltan2.
                                                            ! Z2_NO_TASK_MAPPING        (1) - is no task mapping
                                                            ! Z2_TASK_MAPPING           (2) - performs default task mapping of zoltan2.
                                                            ! Z2_OPTIMIZED_TASK_MAPPING (3) - includes network aware optimizations.
                                                            ! Use (3) if zoltan2 is enabled.

  integer              , public :: partmethod     ! partition methods
  character(len=MAX_STRING_LEN)    , public :: topology       ! options: "cube" is supported
  character(len=MAX_STRING_LEN)    , public :: test_case      ! options: if cube: "swtc1","swtc2",or "swtc6"  
  integer              , public :: tasknum
  integer              , public :: statefreq      ! output frequency of synopsis of system state (steps)
  integer              , public :: restartfreq
  integer              , public :: runtype 
  integer              , public :: timerdetail 
  integer              , public :: numnodes 
  logical              , public :: uselapi
  character(len=MAX_STRING_LEN)    , public :: restartfile 
  character(len=MAX_STRING_LEN)    , public :: restartdir

! namelist variable set to dry,notdry,moist
! internally the code should use logical "use_moisture"
  character(len=MAX_STRING_LEN)    , public :: moisture  

  integer, public  :: use_cpstar=0          ! use cp or cp* in thermodynamics
  logical, public  :: use_moisture=.false.  ! use Q(:,:,:,1) to compute T_v

  
  integer              , public :: maxits         ! max iterations of solver
  real (kind=real_kind), public :: tol            ! solver tolerance (convergence criteria)
  integer              , public :: debug_level    ! debug level of CG solver


  character(len=MAX_STRING_LEN)    ,public  :: vfile_int=""   ! vertical formulation (ecmwf,ccm1)
  character(len=MAX_STRING_LEN)    ,public  :: vfile_mid=""   ! vertical grid spacing (equal,unequal)
  character(len=MAX_STRING_LEN)    ,public  :: vform = ""     ! vertical coordinate system (sigma,hybrid)
  integer,                          public  :: vanalytic = 0  ! if 1, test initializes vertical coords
  real (kind=real_kind),            public  :: vtop = 0.1     ! top coordinate level for analytic vcoords

  integer              , public :: fine_ne = -1               ! set for refined exodus meshes (variable viscosity)
  real (kind=real_kind), public :: max_hypervis_courant = 1d99! upper bound for Courant number
                                                              ! (only used for variable viscosity, recommend 1.9 in namelist)
  real (kind=real_kind), public :: nu      = 7.0D5            ! viscosity (momentum equ)
  real (kind=real_kind), public :: nu_div  = -1               ! viscsoity (momentum equ, div component)
  real (kind=real_kind), public :: nu_s    = -1               ! default = nu   T equ. viscosity
  real (kind=real_kind), public :: nu_q    = -1               ! default = nu   tracer viscosity
  real (kind=real_kind), public :: nu_p    = 0.0D5            ! default = 0    ps equ. viscosity
  real (kind=real_kind), public :: nu_top  = 0.0D5            ! top-of-the-model viscosity

  integer, public :: hypervis_subcycle=1                      ! number of subcycles for hyper viscsosity timestep
  integer, public :: hypervis_subcycle_tom=0                  ! number of subcycles for TOM diffusion
                                                              !   0   apply together with hyperviscosity
                                                              !   >1  apply timesplit from hyperviscosity
  integer, public :: hypervis_subcycle_q=1                    ! number of subcycles for hyper viscsosity timestep on TRACERS
  integer, public :: hypervis_order=0                         ! laplace**hypervis_order.  0=not used  1=regular viscosity, 2=grad**4
  integer, public :: psurf_vis = 0                            ! 0 = use laplace on eta surfaces
                                                              ! 1 = use (approx.) laplace on p surfaces

  real (kind=real_kind), public :: hypervis_power=0           ! if not 0, use variable hyperviscosity based on element area
  real (kind=real_kind), public :: hypervis_scaling=0         ! use tensor hyperviscosity

  !three types of hyper viscosity are supported right now:
  ! (1) const hv:    nu * del^2 del^2
  ! (2) scalar hv:   nu(lat,lon) * del^2 del^2
  ! (3) tensor hv,   nu * ( \div * tensor * \grad ) * del^2
  !
  ! (1) default:  hypervis_power=0, hypervis_scaling=0
  ! (2) Original version for var-res grids. (M. Levy)
  !            scalar coefficient within each element
  !            hypervisc_scaling=0
  !            set hypervis_power>0 and set fine_ne, max_hypervis_courant
  ! (3) tensor HV var-res grids 
  !            tensor within each element:
  !            set hypervis_scaling > 0 (typical values would be 3.2 or 4.0)
  !            hypervis_power=0
  !            (\div * tensor * \grad) operator uses cartesian laplace
  !

  ! hyperviscosity parameters used for smoothing topography
  integer, public :: smooth_phis_numcycle = 0   ! 0 = disable
  real (kind=real_kind), public :: smooth_phis_nudt = 0

  integer, public :: prescribed_wind=0    ! fix the velocities?


  integer, public, parameter :: west  = 1
  integer, public, parameter :: east  = 2
  integer, public, parameter :: south = 3
  integer, public, parameter :: north = 4
  integer, public, parameter :: swest = 5
  integer, public, parameter :: seast = 6
  integer, public, parameter :: nwest = 7
  integer, public, parameter :: neast = 8
  
  logical, public :: disable_diagnostics  = .FALSE.

  ! Physgrid parameters
  integer, public :: se_fv_phys_remap_alg = 0



!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! test case global parameters
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  ! generic test case parameter - can be used by any test case to define options
  integer, public :: sub_case = 1                  

  real (kind=real_kind), public :: initial_total_mass = 0    ! initial perturbation in JW test case
  real (kind=real_kind), public :: u_perturb   = 0         ! initial perturbation in JW test case
#ifndef CAM
  real (kind=real_kind), public :: pertlim = 0          !pertibation to temperature [like CESM]
#endif

  ! shallow water advection test paramters
  ! kmass = level index with density.  other levels contain test tracers
  integer, public  :: kmass  = -1
  integer, public  :: toy_chemistry = 0            !  1 = toy chemestry is turned on in 2D advection code
  real (kind=real_kind), public :: g_sw_output            	   = 9.80616D0          ! m s^-2

  ! parameters for dcmip12 test 2-0: steady state atmosphere with orography
  real(real_kind), public :: dcmip2_0_h0      = 2000.d0        ! height of mountain range        (meters)
  real(real_kind), public :: dcmip2_0_Rm      = 3.d0*dd_pi/4.d0   ! radius of mountain range        (radians)
  real(real_kind), public :: dcmip2_0_zetam   = dd_pi/16.d0       ! mountain oscillation half-width (radians)

  ! parameters for dcmip12 test 2-x: mountain waves
  real(real_kind), public :: dcmip2_x_ueq     = 20.d0          ! wind speed at equator (m/s)
  real(real_kind), public :: dcmip2_x_h0      = 250.0d0        ! mountain height       (m)
  real(real_kind), public :: dcmip2_x_d       = 5000.0d0       ! mountain half width   (m)
  real(real_kind), public :: dcmip2_x_xi      = 4000.0d0       ! mountain wavelength   (m)

  ! for dcmip 2014 test 4:
  integer,         public :: dcmip4_moist     = 1
  real(real_kind), public :: dcmip4_X         = 1.0d0 

  ! for dcmip 2016 test 2
  integer, public :: dcmip16_prec_type = 0;
  integer, public :: dcmip16_pbl_type  = 0;

  ! for dcmip 2016 test 3
  real (kind=real_kind), public :: dcmip16_mu      = 0        ! additional uniform viscosity (momentum)
  real (kind=real_kind), public :: dcmip16_mu_s    = 0        ! additional uniform viscosity (scalar dynamical variables)
  real (kind=real_kind), public :: dcmip16_mu_q    = -1       ! additional uniform viscosity (scalar tracers); -1 implies it defaults to dcmip16_mu_s value
  real (kind=real_kind), public :: interp_lon0     = 0.0d0
end module control_mod
