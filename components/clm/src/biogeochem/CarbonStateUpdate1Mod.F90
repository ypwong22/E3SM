module CarbonStateUpdate1Mod

  !-----------------------------------------------------------------------
  ! Module for carbon state variable update, non-mortality fluxes.
  !
  ! !USES:
  use shr_kind_mod            , only : r8 => shr_kind_r8
  use shr_log_mod             , only : errMsg => shr_log_errMsg
  use abortutils              , only : endrun
  use clm_time_manager        , only : get_step_size, get_curr_date
  use decompMod               , only : bounds_type
  use clm_varpar              , only : ndecomp_cascade_transitions, nlevdecomp
  use clm_varpar              , only : i_met_lit, i_cel_lit, i_lig_lit, i_cwd
  use clm_varcon              , only : dzsoi_decomp, zsoi
  use clm_varctl              , only : nu_com
  use clm_varctl              , only : use_pflotran, pf_cmode, use_fates
  use pftvarcon               , only : npcropmin, nc3crop
  use CNDecompCascadeConType  , only : decomp_cascade_type
  use CNStateType             , only : cnstate_type
  use CNDecompCascadeConType  , only : decomp_cascade_con
  use CropType                , only : crop_type
                              
  use GridcellDataType        , only : gridcell_carbon_state, gridcell_carbon_flux
  use ColumnDataType          , only : column_carbon_state, column_carbon_flux
  use VegetationType          , only : veg_pp
  use VegetationDataType      , only : vegetation_carbon_state, vegetation_carbon_flux
  use VegetationPropertiesType, only : veg_vp
  !
  implicit none
  save
  private
  !
  ! !PUBLIC MEMBER FUNCTIONS:
  public :: CarbonStateUpdateDynPatch
  public :: CarbonStateUpdate1
  public :: CarbonStateUpdate0
  !-----------------------------------------------------------------------

contains

  !-----------------------------------------------------------------------
  subroutine CarbonStateUpdateDynPatch(bounds, num_soilc_with_inactive, filter_soilc_with_inactive, &
       grc_cs, grc_cf, col_cs, col_cf)
    !
    ! !DESCRIPTION:
    ! Update carbon states based on fluxes from dyn_cnbal_patch
    !
    ! !ARGUMENTS:
    type(bounds_type)      , intent(in)    :: bounds
    integer                , intent(in)    :: num_soilc_with_inactive       ! number of columns in soil filter
    integer                , intent(in)    :: filter_soilc_with_inactive(:) ! soil column filter that includes inactive points
    type(gridcell_carbon_state), intent(inout)  :: grc_cs
    type(gridcell_carbon_flux) , intent(inout)  :: grc_cf
    type(column_carbon_state)  , intent(inout)  :: col_cs
    type(column_carbon_flux)   , intent(in)     :: col_cf
    !
    ! !LOCAL VARIABLES:
    integer  :: c   ! column index
    integer  :: fc  ! column filter index
    integer  :: g   ! gridcell index
    integer  :: j   ! level index
    real(r8) :: dt  ! time step (seconds)

    character(len=*), parameter :: subname = 'CarbonStateUpdateDynPatch'
    !-----------------------------------------------------------------------

    dt = real( get_step_size(), r8 )

    if (.not.use_fates) then

       do g = bounds%begg, bounds%endg
          grc_cs%seedc(g) = grc_cs%seedc(g) &
               - grc_cf%dwt_seedc_to_leaf(g)     * dt &
               - grc_cf%dwt_seedc_to_deadstem(g) * dt
       end do

       do j = 1,nlevdecomp
          do fc = 1, num_soilc_with_inactive
             c = filter_soilc_with_inactive(fc)

             col_cs%decomp_cpools_vr(c,j,i_met_lit) = col_cs%decomp_cpools_vr(c,j,i_met_lit) + &
                  col_cf%dwt_frootc_to_litr_met_c(c,j) * dt
             col_cs%decomp_cpools_vr(c,j,i_cel_lit) = col_cs%decomp_cpools_vr(c,j,i_cel_lit) + &
                  col_cf%dwt_frootc_to_litr_cel_c(c,j) * dt
             col_cs%decomp_cpools_vr(c,j,i_lig_lit) = col_cs%decomp_cpools_vr(c,j,i_lig_lit) + &
                  col_cf%dwt_frootc_to_litr_lig_c(c,j) * dt
             col_cs%decomp_cpools_vr(c,j,i_cwd) = col_cs%decomp_cpools_vr(c,j,i_cwd) + &
                  ( col_cf%dwt_livecrootc_to_cwdc(c,j) + col_cf%dwt_deadcrootc_to_cwdc(c,j) ) * dt

          end do
       end do
    end if

  end subroutine CarbonStateUpdateDynPatch

  !-----------------------------------------------------------------------
  subroutine CarbonStateUpdate0(num_soilp, filter_soilp, veg_cs, veg_cf)
    !
    ! !DESCRIPTION:
    ! On the radiation time step, update cpool carbon state
    !

    ! !ARGUMENTS:
    integer                , intent(in)    :: num_soilp       ! number of soil patches in filter
    integer                , intent(in)    :: filter_soilp(:) ! filter for soil patches
    type(vegetation_carbon_state),intent(inout) :: veg_cs
    type(vegetation_carbon_flux) ,intent(inout) :: veg_cf
    !
    ! !LOCAL VARIABLES:
    integer :: p  ! indices
    integer :: fp ! lake filter indices
    real(r8):: dt ! radiation time step (seconds)
    !-----------------------------------------------------------------------

    ! set time steps
    dt = real( get_step_size(), r8 )

    ! patch loop
    do fp = 1,num_soilp
       p = filter_soilp(fp)
       ! gross photosynthesis fluxes
       veg_cs%cpool(p) = veg_cs%cpool(p) + veg_cf%psnsun_to_cpool(p)*dt
       veg_cs%cpool(p) = veg_cs%cpool(p) + veg_cf%psnshade_to_cpool(p)*dt
    end do

  end subroutine CarbonStateUpdate0

  !-----------------------------------------------------------------------
  subroutine CarbonStateUpdate1(bounds, &
       num_soilc, filter_soilc, &
       num_soilp, filter_soilp, &
       crop_vars, col_cs, veg_cs, col_cf, veg_cf, cnstate_vars)
    !
    ! !DESCRIPTION:
    ! On the radiation time step, update all the prognostic carbon state
    ! variables (except for gap-phase mortality and fire fluxes)
    !
    use tracer_varcon       , only : is_active_betr_bgc
    use subgridAveMod       , only : p2c
    use decompMod           , only : bounds_type  
    use clm_varctl          , only : spinup_state, iulog
    use clm_varpar          , only : ndecomp_pools

    ! !ARGUMENTS:
    type(bounds_type)            , intent(in)    :: bounds  
    integer                      , intent(in)    :: num_soilc       ! number of soil columns filter
    integer                      , intent(in)    :: filter_soilc(:) ! filter for soil columns
    integer                      , intent(in)    :: num_soilp       ! number of soil patches in filter
    integer                      , intent(in)    :: filter_soilp(:) ! filter for soil patches
    type(crop_type)              , intent(inout) :: crop_vars
    type(column_carbon_state)    , intent(inout) :: col_cs
    type(vegetation_carbon_state), intent(inout) :: veg_cs
    type(column_carbon_flux)     , intent(inout) :: col_cf
    type(vegetation_carbon_flux) , intent(inout) :: veg_cf
    type(cnstate_type)           , intent(inout) :: cnstate_vars
    !
    ! !LOCAL VARIABLES:
    integer  :: c,p,i,j,k,l ! indices
    integer  :: fp,fc     ! lake filter indices
    integer  :: year, mon, day, sec
    real(r8) :: dt        ! radiation time step (seconds)
    real(r8) :: spinup_term, burial_rate
    !-----------------------------------------------------------------------

    associate(                                                                                 & 
         ivt                   =>    veg_pp%itype                               , & ! Input:  [integer  (:)     ]  pft vegetation type                                
         woody                 =>    veg_vp%woody                               , & ! Input:  [real(r8) (:)     ]  binary flag for woody lifeform (1=woody, 0=not woody)
         cascade_donor_pool    =>    decomp_cascade_con%cascade_donor_pool      , & ! Input:  [integer  (:)     ]  which pool is C taken from for a given decomposition step
         cascade_receiver_pool =>    decomp_cascade_con%cascade_receiver_pool   , & ! Input:  [integer  (:)     ]  which pool is C added to for a given decomposition step
         harvdate              =>    crop_vars%harvdate_patch                   , & ! Input:  [integer  (:)     ]  harvest date
         spinup_factor         =>    decomp_cascade_con%spinup_factor           , & ! Input:  [real(r8) (:)   ]  spinup accelerated decomposition factor, used to accelerate transport as well
         is_cwd                =>    decomp_cascade_con%is_cwd                    & ! Input:  [logical  (:)     ]  TRUE => pool is a cwd pool 
         )

      ! set time steps
      dt = real( get_step_size(), r8 )

      ! column level fluxes

      if(.not.use_fates) then
         do fc = 1,num_soilc
            c = filter_soilc(fc)
            col_cs%decomp_som2c_vr(c,1:nlevdecomp) = col_cs%decomp_cpools_vr(c,1:nlevdecomp,6)
         end do
      end if
      
      if (.not. is_active_betr_bgc .and. .not.(use_pflotran .and. pf_cmode) .and. .not.use_fates ) then

         ! plant to litter fluxes

         do j = 1,nlevdecomp
            ! column loop
            do fc = 1,num_soilc
               c = filter_soilc(fc)
               ! phenology and dynamic land cover fluxes
               col_cf%decomp_cpools_sourcesink(c,j,i_met_lit) = &
                    col_cf%phenology_c_to_litr_met_c(c,j) * dt
               col_cf%decomp_cpools_sourcesink(c,j,i_cel_lit) = &
                    col_cf%phenology_c_to_litr_cel_c(c,j) * dt
               col_cf%decomp_cpools_sourcesink(c,j,i_lig_lit) = &
                    col_cf%phenology_c_to_litr_lig_c(c,j) * dt
            end do
         end do

         !Peat accumulation model
         call get_curr_date(year, mon, day, sec)
         do j = 1,nlevdecomp-1
           do fc = 1,num_soilc
             c = filter_soilc(fc)
             do i = 1, ndecomp_pools
               if ( spinup_state .eq. 1 ) then
                 spinup_term = spinup_factor(i)
               else
                 spinup_term = 1.
               endif
               if (spinup_term > 1 .and. year >= 40 .and. spinup_state .eq. 1) then
                 burial_rate = 0.000_r8 * spinup_term / cnstate_vars%scalaravg_col(c,j)
               else
                 burial_rate = 0.000_r8 * spinup_term
               end if                       
               
               !if (.not. is_cwd(i)) then
               if (col_cs%decomp_cpools_vr(c,j,i) > col_cs%decomp_cpools_vr(c,j+1,i)) then 
                 col_cf%decomp_cpools_sourcesink(c,j,i) = col_cf%decomp_cpools_sourcesink(c,j,i) &
                         - col_cs%decomp_cpools_vr(c,j,i) * &
                         (burial_rate * exp(-(zsoi(j)/0.1_r8)) + 0.0000_r8) / (365.0_r8 * 86400_r8) /dzsoi_decomp(j) * dt
                 col_cf%decomp_cpools_sourcesink(c,j+1,i) = col_cf%decomp_cpools_sourcesink(c,j+1,i) &
                         + col_cs%decomp_cpools_vr(c,j,i) * &
                         (burial_rate * exp(-(zsoi(j)/0.1_r8)) + 0.0000_r8) / (365.0_r8 * 86400_r8) /dzsoi_decomp(j+1) * dt
               end if
             end do
           end do
         end do

         ! litter and SOM HR fluxes
         do k = 1, ndecomp_cascade_transitions
            do j = 1,nlevdecomp
               ! column loop
               do fc = 1,num_soilc
                  c = filter_soilc(fc)
                  col_cf%decomp_cpools_sourcesink(c,j,cascade_donor_pool(k)) = &
                       col_cf%decomp_cpools_sourcesink(c,j,cascade_donor_pool(k)) &
                       - ( col_cf%decomp_cascade_hr_vr(c,j,k) + col_cf%decomp_cascade_ctransfer_vr(c,j,k)) *dt
               end do
            end do
         end do
         do k = 1, ndecomp_cascade_transitions
            if ( cascade_receiver_pool(k) /= 0 ) then  ! skip terminal transitions
               do j = 1,nlevdecomp
                  ! column loop
                  do fc = 1,num_soilc
                     c = filter_soilc(fc)
                     col_cf%decomp_cpools_sourcesink(c,j,cascade_receiver_pool(k)) = &
                          col_cf%decomp_cpools_sourcesink(c,j,cascade_receiver_pool(k)) &
                          + col_cf%decomp_cascade_ctransfer_vr(c,j,k)*dt
                  end do
               end do
            end if
         end do

      elseif( use_fates ) then

         ! The following pools were updated via the FATES interface
         ! col_cf%decomp_cpools_sourcesink(c,j,i_met_lit)
         ! col_cf%decomp_cpools_sourcesink(c,j,i_cel_lit)
         ! col_cf%decomp_cpools_sourcesink(c,j,i_lig_lit)

         ! litter and SOM HR fluxes
         do k = 1, ndecomp_cascade_transitions
            do j = 1,nlevdecomp
               do fc = 1,num_soilc
                  c = filter_soilc(fc)
                  col_cf%decomp_cpools_sourcesink(c,j,cascade_donor_pool(k)) = &
                        col_cf%decomp_cpools_sourcesink(c,j,cascade_donor_pool(k)) &
                        - ( col_cf%decomp_cascade_hr_vr(c,j,k) + col_cf%decomp_cascade_ctransfer_vr(c,j,k)) *dt
               end do
            end do
         end do
         do k = 1, ndecomp_cascade_transitions
            if ( cascade_receiver_pool(k) /= 0 ) then  ! skip terminal transitions
               do j = 1,nlevdecomp
                  do fc = 1,num_soilc
                     c = filter_soilc(fc)
                     col_cf%decomp_cpools_sourcesink(c,j,cascade_receiver_pool(k)) = &
                           col_cf%decomp_cpools_sourcesink(c,j,cascade_receiver_pool(k)) &
                           + col_cf%decomp_cascade_ctransfer_vr(c,j,k)*dt
                  end do
               end do
            end if
         end do

   endif   !end if is_active_betr_bgc()

   if (.not.use_fates) then


      ! patch loop
      do fp = 1,num_soilp
         p = filter_soilp(fp)

         ! phenology: transfer growth fluxes
         veg_cs%leafc(p)           = veg_cs%leafc(p)       + veg_cf%leafc_xfer_to_leafc(p)*dt
         veg_cs%leafc_xfer(p)      = veg_cs%leafc_xfer(p)  - veg_cf%leafc_xfer_to_leafc(p)*dt
         veg_cs%frootc(p)          = veg_cs%frootc(p)      + veg_cf%frootc_xfer_to_frootc(p)*dt
         veg_cs%frootc_xfer(p)     = veg_cs%frootc_xfer(p) - veg_cf%frootc_xfer_to_frootc(p)*dt
         if (woody(ivt(p)) == 1._r8) then
            veg_cs%livestemc(p)       = veg_cs%livestemc(p)       + veg_cf%livestemc_xfer_to_livestemc(p)*dt
            veg_cs%livestemc_xfer(p)  = veg_cs%livestemc_xfer(p)  - veg_cf%livestemc_xfer_to_livestemc(p)*dt
            veg_cs%deadstemc(p)       = veg_cs%deadstemc(p)       + veg_cf%deadstemc_xfer_to_deadstemc(p)*dt
            veg_cs%deadstemc_xfer(p)  = veg_cs%deadstemc_xfer(p)  - veg_cf%deadstemc_xfer_to_deadstemc(p)*dt
            veg_cs%livecrootc(p)      = veg_cs%livecrootc(p)      + veg_cf%livecrootc_xfer_to_livecrootc(p)*dt
            veg_cs%livecrootc_xfer(p) = veg_cs%livecrootc_xfer(p) - veg_cf%livecrootc_xfer_to_livecrootc(p)*dt
            veg_cs%deadcrootc(p)      = veg_cs%deadcrootc(p)      + veg_cf%deadcrootc_xfer_to_deadcrootc(p)*dt
            veg_cs%deadcrootc_xfer(p) = veg_cs%deadcrootc_xfer(p) - veg_cf%deadcrootc_xfer_to_deadcrootc(p)*dt
         end if
         if (ivt(p) >= npcropmin) then ! skip 2 generic crops
            ! lines here for consistency; the transfer terms are zero
            veg_cs%livestemc(p)       = veg_cs%livestemc(p)      + veg_cf%livestemc_xfer_to_livestemc(p)*dt
            veg_cs%livestemc_xfer(p)  = veg_cs%livestemc_xfer(p) - veg_cf%livestemc_xfer_to_livestemc(p)*dt
            veg_cs%grainc(p)          = veg_cs%grainc(p)         + veg_cf%grainc_xfer_to_grainc(p)*dt
            veg_cs%grainc_xfer(p)     = veg_cs%grainc_xfer(p)    - veg_cf%grainc_xfer_to_grainc(p)*dt
         end if

         ! phenology: litterfall fluxes
         veg_cs%leafc(p) = veg_cs%leafc(p) - veg_cf%leafc_to_litter(p)*dt
         veg_cs%frootc(p) = veg_cs%frootc(p) - veg_cf%frootc_to_litter(p)*dt

         ! livewood turnover fluxes
         if (woody(ivt(p)) == 1._r8) then
            veg_cs%livestemc(p)  = veg_cs%livestemc(p)  - veg_cf%livestemc_to_deadstemc(p)*dt
            veg_cs%deadstemc(p)  = veg_cs%deadstemc(p)  + veg_cf%livestemc_to_deadstemc(p)*dt
            veg_cs%livecrootc(p) = veg_cs%livecrootc(p) - veg_cf%livecrootc_to_deadcrootc(p)*dt
            veg_cs%deadcrootc(p) = veg_cs%deadcrootc(p) + veg_cf%livecrootc_to_deadcrootc(p)*dt
         end if
         if (ivt(p) >= npcropmin) then ! skip 2 generic crops
            veg_cs%livestemc(p)  = veg_cs%livestemc(p)  - veg_cf%livestemc_to_litter(p)*dt
            veg_cs%grainc(p)     = veg_cs%grainc(p)     - veg_cf%grainc_to_food(p)*dt

            veg_cs%cropseedc_deficit(p) = veg_cs%cropseedc_deficit(p) &
                 - veg_cf%crop_seedc_to_leaf(p) * dt
         end if

         ! maintenance respiration fluxes from cpool
         veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_to_xsmrpool(p)*dt
         veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%leaf_curmr(p)*dt
         veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%froot_curmr(p)*dt
         if (woody(ivt(p)) == 1._r8) then
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%livestem_curmr(p)*dt
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%livecroot_curmr(p)*dt
         end if
         if (ivt(p) >= npcropmin) then ! skip 2 generic crops
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%livestem_curmr(p)*dt
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%grain_curmr(p)*dt
         end if
         ! excess respiration flux from cpool
         veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%xr(p)*dt

         ! maintenance respiration fluxes from xsmrpool
         veg_cs%xsmrpool(p) = veg_cs%xsmrpool(p) + veg_cf%cpool_to_xsmrpool(p)*dt
         veg_cs%xsmrpool(p) = veg_cs%xsmrpool(p) - veg_cf%leaf_xsmr(p)*dt
         veg_cs%xsmrpool(p) = veg_cs%xsmrpool(p) - veg_cf%froot_xsmr(p)*dt
         if (nu_com .ne. 'RD') then
            veg_cs%xsmrpool(p) = veg_cs%xsmrpool(p) - veg_cf%xsmrpool_turnover(p)*dt
         end if
         if (woody(ivt(p)) == 1._r8) then
            veg_cs%xsmrpool(p) = veg_cs%xsmrpool(p) - veg_cf%livestem_xsmr(p)*dt
            veg_cs%xsmrpool(p) = veg_cs%xsmrpool(p) - veg_cf%livecroot_xsmr(p)*dt
         end if
         if (ivt(p) >= npcropmin) then ! skip 2 generic crops
            veg_cs%xsmrpool(p) = veg_cs%xsmrpool(p) - veg_cf%livestem_xsmr(p)*dt
            veg_cs%xsmrpool(p) = veg_cs%xsmrpool(p) - veg_cf%grain_xsmr(p)*dt
            if (harvdate(p) < 999) then ! beginning at harvest, send to atm
               veg_cf%xsmrpool_to_atm(p) = veg_cf%xsmrpool_to_atm(p) + veg_cs%xsmrpool(p)/dt
               veg_cs%xsmrpool(p)        = veg_cs%xsmrpool(p)        - veg_cf%xsmrpool_to_atm(p)*dt
            end if
         end if

         ! allocation fluxes
         veg_cs%cpool(p)           = veg_cs%cpool(p)          - veg_cf%cpool_to_leafc(p)*dt
         veg_cs%leafc(p)           = veg_cs%leafc(p)          + veg_cf%cpool_to_leafc(p)*dt
         veg_cs%cpool(p)           = veg_cs%cpool(p)          - veg_cf%cpool_to_leafc_storage(p)*dt
         veg_cs%leafc_storage(p)   = veg_cs%leafc_storage(p)  + veg_cf%cpool_to_leafc_storage(p)*dt
         veg_cs%cpool(p)           = veg_cs%cpool(p)          - veg_cf%cpool_to_frootc(p)*dt
         veg_cs%frootc(p)          = veg_cs%frootc(p)         + veg_cf%cpool_to_frootc(p)*dt
         veg_cs%cpool(p)           = veg_cs%cpool(p)          - veg_cf%cpool_to_frootc_storage(p)*dt
         veg_cs%frootc_storage(p)  = veg_cs%frootc_storage(p) + veg_cf%cpool_to_frootc_storage(p)*dt
         if (woody(ivt(p)) == 1._r8) then
            veg_cs%cpool(p)               = veg_cs%cpool(p)              - veg_cf%cpool_to_livestemc(p)*dt
            veg_cs%livestemc(p)           = veg_cs%livestemc(p)          + veg_cf%cpool_to_livestemc(p)*dt
            veg_cs%cpool(p)               = veg_cs%cpool(p)              - veg_cf%cpool_to_livestemc_storage(p)*dt
            veg_cs%livestemc_storage(p)   = veg_cs%livestemc_storage(p)  + veg_cf%cpool_to_livestemc_storage(p)*dt
            veg_cs%cpool(p)               = veg_cs%cpool(p)              - veg_cf%cpool_to_deadstemc(p)*dt
            veg_cs%deadstemc(p)           = veg_cs%deadstemc(p)          + veg_cf%cpool_to_deadstemc(p)*dt
            veg_cs%cpool(p)               = veg_cs%cpool(p)              - veg_cf%cpool_to_deadstemc_storage(p)*dt
            veg_cs%deadstemc_storage(p)   = veg_cs%deadstemc_storage(p)  + veg_cf%cpool_to_deadstemc_storage(p)*dt
            veg_cs%cpool(p)               = veg_cs%cpool(p)              - veg_cf%cpool_to_livecrootc(p)*dt
            veg_cs%livecrootc(p)          = veg_cs%livecrootc(p)         + veg_cf%cpool_to_livecrootc(p)*dt
            veg_cs%cpool(p)               = veg_cs%cpool(p)              - veg_cf%cpool_to_livecrootc_storage(p)*dt
            veg_cs%livecrootc_storage(p)  = veg_cs%livecrootc_storage(p) + veg_cf%cpool_to_livecrootc_storage(p)*dt
            veg_cs%cpool(p)               = veg_cs%cpool(p)              - veg_cf%cpool_to_deadcrootc(p)*dt
            veg_cs%deadcrootc(p)          = veg_cs%deadcrootc(p)         + veg_cf%cpool_to_deadcrootc(p)*dt
            veg_cs%cpool(p)               = veg_cs%cpool(p)              - veg_cf%cpool_to_deadcrootc_storage(p)*dt
            veg_cs%deadcrootc_storage(p)  = veg_cs%deadcrootc_storage(p) + veg_cf%cpool_to_deadcrootc_storage(p)*dt
         end if
         if (ivt(p) >= npcropmin) then ! skip 2 generic crops
            veg_cs%cpool(p)               = veg_cs%cpool(p)              - veg_cf%cpool_to_livestemc(p)*dt
            veg_cs%livestemc(p)           = veg_cs%livestemc(p)          + veg_cf%cpool_to_livestemc(p)*dt
            veg_cs%cpool(p)               = veg_cs%cpool(p)              - veg_cf%cpool_to_livestemc_storage(p)*dt
            veg_cs%livestemc_storage(p)   = veg_cs%livestemc_storage(p)  + veg_cf%cpool_to_livestemc_storage(p)*dt
            veg_cs%cpool(p)               = veg_cs%cpool(p)              - veg_cf%cpool_to_grainc(p)*dt
            veg_cs%grainc(p)              = veg_cs%grainc(p)             + veg_cf%cpool_to_grainc(p)*dt
            veg_cs%cpool(p)               = veg_cs%cpool(p)              - veg_cf%cpool_to_grainc_storage(p)*dt
            veg_cs%grainc_storage(p)      = veg_cs%grainc_storage(p)     + veg_cf%cpool_to_grainc_storage(p)*dt
         end if

         ! growth respiration fluxes for current growth
         veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_leaf_gr(p)*dt
         veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_froot_gr(p)*dt
         if (woody(ivt(p)) == 1._r8) then
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_livestem_gr(p)*dt
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_deadstem_gr(p)*dt
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_livecroot_gr(p)*dt
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_deadcroot_gr(p)*dt
         end if
         if (ivt(p) >= npcropmin) then ! skip 2 generic crops
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_livestem_gr(p)*dt
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_grain_gr(p)*dt
         end if

         ! growth respiration for transfer growth
         veg_cs%gresp_xfer(p) = veg_cs%gresp_xfer(p) - veg_cf%transfer_leaf_gr(p)*dt
         veg_cs%gresp_xfer(p) = veg_cs%gresp_xfer(p) - veg_cf%transfer_froot_gr(p)*dt
         if (woody(ivt(p)) == 1._r8) then
            veg_cs%gresp_xfer(p) = veg_cs%gresp_xfer(p) - veg_cf%transfer_livestem_gr(p)*dt
            veg_cs%gresp_xfer(p) = veg_cs%gresp_xfer(p) - veg_cf%transfer_deadstem_gr(p)*dt
            veg_cs%gresp_xfer(p) = veg_cs%gresp_xfer(p) - veg_cf%transfer_livecroot_gr(p)*dt
            veg_cs%gresp_xfer(p) = veg_cs%gresp_xfer(p) - veg_cf%transfer_deadcroot_gr(p)*dt
         end if
         if (ivt(p) >= npcropmin) then ! skip 2 generic crops
            veg_cs%gresp_xfer(p) = veg_cs%gresp_xfer(p) - veg_cf%transfer_livestem_gr(p)*dt
            veg_cs%gresp_xfer(p) = veg_cs%gresp_xfer(p) - veg_cf%transfer_grain_gr(p)*dt
         end if

         ! growth respiration at time of storage
         veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_leaf_storage_gr(p)*dt
         veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_froot_storage_gr(p)*dt
         if (woody(ivt(p)) == 1._r8) then
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_livestem_storage_gr(p)*dt
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_deadstem_storage_gr(p)*dt
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_livecroot_storage_gr(p)*dt
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_deadcroot_storage_gr(p)*dt
         end if
         if (ivt(p) >= npcropmin) then ! skip 2 generic crops
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_livestem_storage_gr(p)*dt
            veg_cs%cpool(p) = veg_cs%cpool(p) - veg_cf%cpool_grain_storage_gr(p)*dt
         end if

         ! growth respiration stored for release during transfer growth
         veg_cs%cpool(p)         = veg_cs%cpool(p)         - veg_cf%cpool_to_gresp_storage(p)*dt
         veg_cs%gresp_storage(p) = veg_cs%gresp_storage(p) + veg_cf%cpool_to_gresp_storage(p)*dt

         ! move storage pools into transfer pools
         veg_cs%leafc_storage(p)  = veg_cs%leafc_storage(p)  - veg_cf%leafc_storage_to_xfer(p)*dt
         veg_cs%leafc_xfer(p)     = veg_cs%leafc_xfer(p)     + veg_cf%leafc_storage_to_xfer(p)*dt
         veg_cs%frootc_storage(p) = veg_cs%frootc_storage(p) - veg_cf%frootc_storage_to_xfer(p)*dt
         veg_cs%frootc_xfer(p)    = veg_cs%frootc_xfer(p)    + veg_cf%frootc_storage_to_xfer(p)*dt
         if (woody(ivt(p)) == 1._r8) then
            veg_cs%livestemc_storage(p)  = veg_cs%livestemc_storage(p) - veg_cf%livestemc_storage_to_xfer(p)*dt
            veg_cs%livestemc_xfer(p)     = veg_cs%livestemc_xfer(p)    + veg_cf%livestemc_storage_to_xfer(p)*dt
            veg_cs%deadstemc_storage(p)  = veg_cs%deadstemc_storage(p) - veg_cf%deadstemc_storage_to_xfer(p)*dt
            veg_cs%deadstemc_xfer(p)     = veg_cs%deadstemc_xfer(p)    + veg_cf%deadstemc_storage_to_xfer(p)*dt
            veg_cs%livecrootc_storage(p) = veg_cs%livecrootc_storage(p)- veg_cf%livecrootc_storage_to_xfer(p)*dt
            veg_cs%livecrootc_xfer(p)    = veg_cs%livecrootc_xfer(p)   + veg_cf%livecrootc_storage_to_xfer(p)*dt
            veg_cs%deadcrootc_storage(p) = veg_cs%deadcrootc_storage(p)- veg_cf%deadcrootc_storage_to_xfer(p)*dt
            veg_cs%deadcrootc_xfer(p)    = veg_cs%deadcrootc_xfer(p)   + veg_cf%deadcrootc_storage_to_xfer(p)*dt
            veg_cs%gresp_storage(p)      = veg_cs%gresp_storage(p)     - veg_cf%gresp_storage_to_xfer(p)*dt
            veg_cs%gresp_xfer(p)         = veg_cs%gresp_xfer(p)        + veg_cf%gresp_storage_to_xfer(p)*dt
         end if
         if (ivt(p) >= npcropmin) then ! skip 2 generic crops
            ! lines here for consistency; the transfer terms are zero
            veg_cs%livestemc_storage(p)  = veg_cs%livestemc_storage(p) - veg_cf%livestemc_storage_to_xfer(p)*dt
            veg_cs%livestemc_xfer(p)     = veg_cs%livestemc_xfer(p)    + veg_cf%livestemc_storage_to_xfer(p)*dt
            veg_cs%grainc_storage(p)     = veg_cs%grainc_storage(p)    - veg_cf%grainc_storage_to_xfer(p)*dt
            veg_cs%grainc_xfer(p)        = veg_cs%grainc_xfer(p)       + veg_cf%grainc_storage_to_xfer(p)*dt
         end if

      end do ! end of patch loop

   end if

 end associate

end subroutine CarbonStateUpdate1

end module CarbonStateUpdate1Mod