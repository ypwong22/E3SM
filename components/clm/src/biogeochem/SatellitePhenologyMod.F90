module SatellitePhenologyMod

  !-----------------------------------------------------------------------
  ! !DESCRIPTION:
  ! CLM Satelitte Phenology model (SP) ecosystem dynamics (phenology, vegetation). 
  ! Allow some subroutines to be used by the CLM Carbon Nitrogen model (CLMCN) 
  ! so that DryDeposition code can get estimates of LAI differences between months.
  !
  ! !USES:
  use shr_strdata_mod , only : shr_strdata_type, shr_strdata_create
  use shr_strdata_mod , only : shr_strdata_print, shr_strdata_advance
  use shr_const_mod   , only : SHR_CONST_TKFRZ
  use shr_kind_mod    , only : r8 => shr_kind_r8
  use shr_kind_mod    , only : CL => shr_kind_CL
  use shr_log_mod     , only : errMsg => shr_log_errMsg
  use decompMod       , only : bounds_type
  use abortutils      , only : endrun
  use clm_varctl      , only : scmlat,scmlon,single_column
  use clm_varctl      , only : iulog, use_lai_streams, use_cn
  use clm_varcon      , only : grlnd
  use controlMod      , only : NLFilename
  use decompMod       , only : gsmap_lnd_gdc2glo
  use domainMod       , only : ldomain
  use fileutils       , only : getavu, relavu
  use GridcellType         , only : grc_pp
  use VegetationType       , only : veg_pp                
  use VegetationDataType   , only : veg_es
  use CanopyStateType , only : canopystate_type
  use WaterstateType  , only : waterstate_type
  use ColumnDataType  , only : col_ws
  use TemperatureType , only : temperature_type
  use SoilstateType   , only : soilstate_type
  use perf_mod        , only : t_startf, t_stopf
  use spmdMod         , only : masterproc
  use spmdMod         , only : mpicom, comp_id
  use mct_mod
  use ncdio_pio   
  !
  ! !PUBLIC TYPES:
  implicit none
  save
  !
  ! !PUBLIC MEMBER FUNCTIONS:
  public :: SatellitePhenology     ! CLMSP Ecosystem dynamics: phenology, vegetation
  public :: SatellitePhenologyInit ! Dynamically allocate memory
  public :: interpMonthlyVeg       ! interpolate monthly vegetation data
  public :: readAnnualVegetation   ! Read in annual vegetation (needed for Dry-deposition)
  !
  ! !PRIVATE MEMBER FUNCTIONS:
  private :: readMonthlyVegetation   ! read monthly vegetation data for two months
  private :: lai_init    ! position datasets for LAI
  private :: lai_interp  ! interpolates between two years of LAI data

  ! !PRIVATE MEMBER DATA:
  type(shr_strdata_type) :: sdat_lai           ! LAI input data stream
  !
  ! !PRIVATE TYPES:
  integer , private :: InterpMonths1            ! saved month index
  real(r8), private :: timwt(2)                 ! time weights for month 1 and month 2
  real(r8), private, allocatable :: mlai2t(:,:) ! lai for interpolation (2 months)
  real(r8), private, allocatable :: msai2t(:,:) ! sai for interpolation (2 months)
  real(r8), private, allocatable :: mhvt2t(:,:) ! top vegetation height for interpolation (2 months)
  real(r8), private, allocatable :: mhvb2t(:,:) ! bottom vegetation height for interpolation(2 months)
  !-----------------------------------------------------------------------

contains
  
  !-----------------------------------------------------------------------
  !
  ! lai_init
  !
  !-----------------------------------------------------------------------
  subroutine lai_init(bounds)
    !
    ! Initialize data stream information for LAI.
    !
    !
    ! !USES:
    use clm_varctl       , only : inst_name
    use clm_time_manager , only : get_calendar
    use ncdio_pio        , only : pio_subsystem
    use shr_pio_mod      , only : shr_pio_getiotype
    use clm_nlUtilsMod   , only : find_nlgroup_name
    use ndepStreamMod    , only : clm_domain_mct
    use histFileMod      , only : hist_addfld1d
    use shr_stream_mod   , only : shr_stream_file_null
    use shr_string_mod   , only : shr_string_listCreateField
    !
    ! !ARGUMENTS:
    implicit none
    type(bounds_type), intent(in) :: bounds          ! bounds
    !
    ! !LOCAL VARIABLES:
    integer            :: i                          ! index
    integer            :: stream_year_first_lai      ! first year in Lai stream to use
    integer            :: stream_year_last_lai       ! last year in Lai stream to use
    integer            :: model_year_align_lai       ! align stream_year_first_lai with 
    integer            :: nu_nml                     ! unit for namelist file
    integer            :: nml_error                  ! namelist i/o error flag
    type(mct_ggrid)    :: dom_clm                    ! domain information 
    character(len=CL)  :: stream_fldFileName_lai     ! lai stream filename to read
    character(len=CL)  :: lai_mapalgo = 'bilinear'   ! Mapping alogrithm

    character(*), parameter    :: subName = "('laidyn_init')"
    character(*), parameter    :: F00 = "('(laidyn_init) ',4a)"
    character(*), parameter    :: laiString = "LAI"  ! base string for field string
    integer     , parameter    :: numLaiFields = 16  ! number of fields to build field string
    character(SHR_KIND_CXX)    :: fldList            ! field string
    !-----------------------------------------------------------------------
    !
    ! deal with namelist variables here in init
    !
    namelist /lai_streams/         &
         stream_year_first_lai,    &
         stream_year_last_lai,     &
         model_year_align_lai,     &
         lai_mapalgo,              &
         stream_fldFileName_lai

    ! Default values for namelist
    stream_year_first_lai     = 1      ! first year in stream to use
    stream_year_last_lai      = 1      ! last  year in stream to use
    model_year_align_lai      = 1      ! align stream_year_first_lai with this model year
    stream_fldFileName_lai    = shr_stream_file_null

    ! Read lai_streams namelist
    if (masterproc) then
       nu_nml = getavu()
       open( nu_nml, file=trim(NLFilename), status='old', iostat=nml_error )
       call find_nlgroup_name(nu_nml, 'lai_streams', status=nml_error)
       if (nml_error == 0) then
          read(nu_nml, nml=lai_streams,iostat=nml_error)
          if (nml_error /= 0) then
             call endrun(subname // ':: ERROR reading lai_streams namelist')
          end if
       end if
       close(nu_nml)
       call relavu( nu_nml )
    endif

    call shr_mpi_bcast(stream_year_first_lai, mpicom)
    call shr_mpi_bcast(stream_year_last_lai, mpicom)
    call shr_mpi_bcast(model_year_align_lai, mpicom)
    call shr_mpi_bcast(stream_fldFileName_lai, mpicom)

    if (masterproc) then

       write(iulog,*) ' '
       write(iulog,*) 'lai_stream settings:'
       write(iulog,*) '  stream_year_first_lai  = ',stream_year_first_lai  
       write(iulog,*) '  stream_year_last_lai   = ',stream_year_last_lai   
       write(iulog,*) '  model_year_align_lai   = ',model_year_align_lai   
       write(iulog,*) '  stream_fldFileName_lai = ',trim(stream_fldFileName_lai)

    endif

    call clm_domain_mct (bounds, dom_clm)

    !
    ! create the field list for these lai fields...use in shr_strdata_create
    !
    fldList = shr_string_listCreateField( numLaiFields, laiString )

    call shr_strdata_create(sdat_lai,name="laidyn",    &
         pio_subsystem=pio_subsystem,                  & 
         pio_iotype=shr_pio_getiotype(inst_name),      &
         mpicom=mpicom, compid=comp_id,                &
         gsmap=gsmap_lnd_gdc2glo, ggrid=dom_clm,       &
         nxg=ldomain%ni, nyg=ldomain%nj,               &
         yearFirst=stream_year_first_lai,              &
         yearLast=stream_year_last_lai,                &
         yearAlign=model_year_align_lai,               &
         offset=0,                                     &
         domFilePath='',                               &
         domFileName=trim(stream_fldFileName_lai),  &
         domTvarName='time',                           &
         domXvarName='lon' ,                           &
         domYvarName='lat' ,                           &  
         domAreaName='area',                           &
         domMaskName='mask',                           &
         filePath='',                                  &
         filename=(/stream_fldFileName_lai/),          &
         fldListFile=fldList,                          &
         fldListModel=fldList,                         &
         fillalgo='none',                              &
         mapalgo=lai_mapalgo,                          &
         calendar=get_calendar(),                      &
         taxmode='cycle'                               )

    if (masterproc) then
       call shr_strdata_print(sdat_lai,'LAI data')
    endif

  end subroutine lai_init

  !-----------------------------------------------------------------------
  !
  ! lai_interp
  !
  !-----------------------------------------------------------------------
  subroutine lai_interp(bounds, canopystate_vars)
    !
    ! Interpolate data stream information for Lai.
    !
    ! !USES:
    use clm_time_manager, only : get_curr_date
    use pftvarcon       , only : noveg
    !
    ! !ARGUMENTS:
    implicit none
    type(bounds_type)      , intent(in)    :: bounds                          
    type(canopystate_type) , intent(inout) :: canopystate_vars
    !
    ! !LOCAL VARIABLES:
    integer :: ivt, p, g, ip, ig, gpft
    integer :: year    ! year (0, ...) for nstep+1
    integer :: mon     ! month (1, ..., 12) for nstep+1
    integer :: day     ! day of month (1, ..., 31) for nstep+1
    integer :: sec     ! seconds into current date for nstep+1
    integer :: mcdate  ! Current model date (yyyymmdd)
    character(len=CL)  :: stream_var_name
    !-----------------------------------------------------------------------

    call get_curr_date(year, mon, day, sec)
    mcdate = year*10000 + mon*100 + day

    call shr_strdata_advance(sdat_lai, mcdate, sec, mpicom, 'laidyn')

    do p = bounds%begp, bounds%endp
       ivt = veg_pp%itype(p)
       if (ivt /= noveg) then     ! vegetated pft
          write(stream_var_name,"(i6)") ivt
          stream_var_name = 'LAI_'//trim(adjustl(stream_var_name))
          ip = mct_aVect_indexRA(sdat_lai%avs(1),trim(stream_var_name))
       endif
       gpft = veg_pp%gridcell(p)

       !
       ! Determine vector index corresponding to gpft
       !
       ig = 0
       do g = bounds%begg,bounds%endg
          ig = ig+1
          if (g == gpft) exit
       end do

       !
       ! Set lai for each gridcell/patch combination
       !
       if (ivt /= noveg) then     ! vegetated pft
          canopystate_vars%tlai_patch(p) = sdat_lai%avs(1)%rAttr(ip,ig)
       else                       ! non-vegetated pft
          canopystate_vars%tlai_patch(p) = 0._r8
       endif
    end do

  end subroutine lai_interp

  !-----------------------------------------------------------------------
  subroutine SatellitePhenologyInit (bounds)
    !
    ! !DESCRIPTION:
    ! Dynamically allocate memory and set to signaling NaN.
    !
    ! !USES:
    use shr_infnan_mod, only : nan => shr_infnan_nan, assignment(=)
    !
    ! !ARGUMENTS:
    type(bounds_type), intent(in) :: bounds  
    !
    ! !LOCAL VARIABLES:
    integer :: ier    ! error code
    !-----------------------------------------------------------------------

    InterpMonths1 = -999  ! saved month index

    ier = 0
    if(.not.allocated(mlai2t)) then
       allocate (mlai2t(bounds%begp:bounds%endp,2), &
            msai2t(bounds%begp:bounds%endp,2), &
            mhvt2t(bounds%begp:bounds%endp,2), &
            mhvb2t(bounds%begp:bounds%endp,2), stat=ier)
    end if
    if (ier /= 0) then
       write(iulog,*) 'EcosystemDynini allocation error'
       call endrun(msg=errMsg(__FILE__, __LINE__))
    end if

    mlai2t(bounds%begp : bounds%endp, :) = nan
    msai2t(bounds%begp : bounds%endp, :) = nan
    mhvt2t(bounds%begp : bounds%endp, :) = nan
    mhvb2t(bounds%begp : bounds%endp, :) = nan

    if (use_lai_streams) then
       call lai_init(bounds)
    endif

  end subroutine SatellitePhenologyInit

  !-----------------------------------------------------------------------
  subroutine SatellitePhenology(bounds, num_nolakep, filter_nolakep, &
       waterstate_vars, canopystate_vars, temperature_vars, soilstate_vars)
    !
    ! !DESCRIPTION:
    ! Ecosystem dynamics: phenology, vegetation
    ! Calculates leaf areas (tlai, elai),  stem areas (tsai, esai) and height
    ! (htop).
    !
    ! !USES:
    use clm_time_manager, only : get_curr_date, get_step_size, get_nstep
    use clm_varcon      , only : secspday
    use pftvarcon, only : noveg, nbrdlf_dcd_brl_shrub, season_decid, stress_decid
#if defined HUM_HOL
    use pftvarcon, only : phen_a, phen_b, phen_c, phen_topt, phen_fstar, phen_tc
    use pftvarcon, only : phen_cstar, phen_tforce, phen_tchil, phen_pstart, phen_tb, phen_ycrit 
    use pftvarcon, only : phen_spring, phen_autumn, phen_tbase
#endif
    !
    ! !ARGUMENTS:
    type(bounds_type)      , intent(in)    :: bounds                          
    integer                , intent(in)    :: num_nolakep ! number of column non-lake points in pft filter
    integer                , intent(in)    :: filter_nolakep(bounds%endp-bounds%begp+1) ! patch filter for non-lake points
    type(waterstate_type)  , intent(in)    :: waterstate_vars
    type(soilstate_type)   , intent(in)    :: soilstate_vars
    type(temperature_type) , intent(in)    :: temperature_vars
    type(canopystate_type) , intent(inout) :: canopystate_vars
    !
    ! !LOCAL VARIABLES::
    integer  :: fp,g,p,c                            ! indices
    real(r8) :: ol                                ! thickness of canopy layer covered by snow (m)
    real(r8) :: fb                                ! fraction of canopy layer covered by snow
    real(r8) :: onset_gdd, fracday, dt, crit_dayl, ndays_on, ndays_off
    real(r8) :: soilpsi_off, soilpsi_on, crit_onset_swi, crit_offset_swi
    real(r8) :: crit_offset_fdd, crit_onset_fdd, ws_flag, crit_onset_gdd
    integer spring_threshold, autumn_threshold
    !-----------------------------------------------------------------------
 
    associate(                                                           &
         frac_sno           => col_ws%frac_sno   ,          & ! Input:  [real(r8) (:) ] fraction of ground covered by snow (0 to 1)       
         snow_depth         => col_ws%snow_depth ,          & ! Input:  [real(r8) (:) ] snow height (m)                                                       
         dayl               => grc_pp%dayl,                              & ! Input:  [real(r8)  (:)   ]  daylength (s)
         prev_dayl          => grc_pp%prev_dayl,                         & ! Input:  [real(r8)  (:)   ]  previous daylength (s)
         t_ref2m            => temperature_vars%t_ref2m_patch ,          & ! Input:  [real(r8) (:) ] 2-meter air temperature (K)
         t_soisno           => temperature_vars%t_soisno_col  ,          & ! Input : [real(r8) (:) ] soil temperature (K)      
         tmean              => veg_es%t_2m3650       ,                   & ! Input:[real(r8) (:)   ]  10-year running mean of the 2 m temperature (K)                    
         soilpsi            => soilstate_vars%soilpsi_col     ,          & ! Input: [real(r8)  (:,:) ]  soil water potential in each soil layer (MPa) 
         tlai               => canopystate_vars%tlai_patch    ,          & ! Output: [real(r8) (:) ] one-sided leaf area index, no burying by snow 
         tsai               => canopystate_vars%tsai_patch    ,          & ! Output: [real(r8) (:) ] one-sided stem area index, no burying by snow
         elai               => canopystate_vars%elai_patch    ,          & ! Output: [real(r8) (:) ] one-sided leaf area index with burying by snow
         esai               => canopystate_vars%esai_patch    ,          & ! Output: [real(r8) (:) ] one-sided stem area index with burying by snow
         htop               => canopystate_vars%htop_patch    ,          & ! Output: [real(r8) (:) ] canopy top (m)                           
         hbot               => canopystate_vars%hbot_patch    ,          & ! Output: [real(r8) (:) ] canopy bottom (m)                           
         frac_veg_nosno_alb => canopystate_vars%frac_veg_nosno_alb_patch,  & ! Output: [integer  (:) ] fraction of vegetation not covered by snow (0 OR 1) [-]
         sp_gdd             => canopystate_vars%sp_gdd_patch,            & ! Output:
         sp_chil            => canopystate_vars%sp_chil_patch,           & ! Output:
         sp_swi_on          => canopystate_vars%sp_swi_on_patch,         & ! Output:
         sp_swi_off         => canopystate_vars%sp_swi_off_patch,        & ! Output:
         sp_fdd_off         => canopystate_vars%sp_fdd_off_patch,        & ! Output:
         sp_onset_day       => canopystate_vars%sp_onset_day_patch,      & ! Output:
         sp_offset_day      => canopystate_vars%sp_offset_day_patch,     & ! Output:
         sp_dayl_temp       => canopystate_vars%sp_dayl_temp_patch,      & ! Output:
         annlai             => canopystate_vars%annlai_patch,            &
         ivt                => veg_pp%itype                              &
         )
 
      if (use_lai_streams) then
         call lai_interp(bounds, canopystate_vars)
      endif
 
      dt      = real( get_step_size(), r8 )
      fracday = dt/secspday

      do fp = 1, num_nolakep
         p = filter_nolakep(fp)
         g = veg_pp%gridcell(p)
         c = veg_pp%column(p)
 
         ! need to update elai and esai only every albedo time step so do not
         ! have any inconsistency in lai and sai between SurfaceAlbedo calls (i.e.,
         ! if albedos are not done every time step).
         ! leaf phenology
         ! Set leaf and stem areas based on day of year
         ! Interpolate leaf area index, stem area index, and vegetation heights
         ! between two monthly
         ! The weights below (timwt(1) and timwt(2)) were obtained by a call to
         ! routine InterpMonthlyVeg in subroutine NCARlsm.
         !                 Field   Monthly Values
         !                -------------------------
         ! leaf area index LAI  <- mlai1 and mlai2
         ! leaf area index SAI  <- msai1 and msai2
         ! top height      HTOP <- mhvt1 and mhvt2
         ! bottom height   HBOT <- mhvb1 and mhvb2
 
         !Parameter values (note - these should be retrieved from the parameter file)
         ndays_on  = 30._r8
         ndays_off = 15._r8
         crit_onset_swi  = 15._r8
         crit_onset_fdd  = 15._r8  !Functionality not implemented
         crit_offset_swi = 15._r8
         crit_offset_fdd = 15._r8
         soilpsi_off = -2._r8
         soilpsi_on = -2._r8

         if (.not. use_lai_streams) then
            tlai(p) = timwt(1)*mlai2t(p,1) + timwt(2)*mlai2t(p,2)
            !DMR 10.17.18 - Predict seasonal phenology using max monthly LAI
            !from Satellite
            !Check if winter solstice has happened (daylength increasing)
            if (dayl(g) >= prev_dayl(g)) then
              ws_flag = 1._r8
            else
              ws_flag = 0._r8
            end if
            !------ Seasonal deciduous phenology ----------------------
#if defined HUM_HOLXXX
            !crit_onset_gdd = exp(4.8_r8 + 0.13_r8*(tmean(p) - SHR_CONST_TKFRZ))
            crit_onset_gdd = phen_fstar
            if (.not. use_cn .and. season_decid(ivt(p)) == 1._r8) then
               tlai(p) = maxval(annlai(:,p))
               crit_dayl = 39300_r8
               !Spring phenology
               !Increment GDD and chilling days, check threshold according to model formulation
               spring_threshold = 0 
               if (ws_flag == 1._r8 .and. phen_spring == 0) then 
                 !Default model
                 sp_gdd(p) = sp_gdd(p) + max((t_soisno(c,3) - SHR_CONST_TKFRZ)*fracday, 0._r8)
                 if (sp_gdd(p) .ge. crit_onset_gdd) spring_threshold = 1
               else if (ws_flag == 1._r8 .and. phen_spring == 1) then 
                 !PAR model
                 if (t_ref2m(p) > phen_tbase) sp_gdd(p) = sp_gdd(p) + &
                   (28.4_r8 / (1._r8 + exp(3.4_r8 - (t_ref2m(p) -SHR_CONST_TKFRZ)*0.185_r8)))*fracday 
                 if (t_ref2m(p) > phen_topt .and. t_ref2m(p) < (phen_topt + 10.4_r8)) then 
                   sp_chil(p) = sp_chil(p) + (((t_ref2m(p) - SHR_CONST_TKFRZ)-10.4_r8)/(phen_topt-10.4_r8))*fracday 
                 end if
                 if (t_ref2m(p) > phen_topt-3.4_r8 .and. t_ref2m(p) <= phen_topt) then
                   sp_chil(p) = sp_chil(p) + (((t_ref2m(p) - SHR_CONST_TKFRZ)+3.4_r8)/(phen_topt+3.4_r8))*fracday
                 end if
                 if (sp_gdd(p) > phen_a + phen_b * exp(sp_chil(p))) spring_threshold = 1 
               else if (ws_flag == 1._r8 .and. phen_spring == 2) then
                 !ALT model
                 if (t_ref2m(p) > phen_tbase) sp_gdd(p) = sp_gdd(p) + (t_ref2m(p)-phen_tbase)*fracday
                 if (t_ref2m(p) > 263.0_r8 .and. t_ref2m(p) < phen_tbase) sp_chil(p) = sp_chil(p) + fracday
                 if (sp_gdd(p) > phen_a + phen_b * exp(phen_c * sp_chil(p))) spring_threshold = 1
               else if (ws_flag == 1._r8 .and. phen_spring == 3) then 
                 !SEQ model
                 if (t_ref2m(p) < phen_tchil .and. t_ref2m(p) > 263._r8) sp_chil(p)=sp_chil(p)+fracday
                 if (sp_chil(p) > phen_cstar .and. t_ref2m(p) > phen_tforce) then 
                   sp_gdd(p) = sp_gdd(p) + (t_ref2m(p)-phen_tforce)*fracday
                 end if
                 if (sp_gdd(p) > phen_fstar) spring_threshold = 1
               else if (ws_flag == 1._r8 .and. phen_spring == 4) then
                 !SW model
                 sp_gdd(p) = sp_gdd(p) + (28.4_r8 / (1.0_r8 + exp(3.4_r8-(t_ref2m(p)-SHR_CONST_TKFRZ)*0.185_r8)))*fracday
                 if (sp_gdd(p) .ge. phen_fstar) spring_threshold = 1
               end if
               !Increment dayl_temp (DM only)
               if (tlai(p) > 0._r8 .and. dayl(g) < phen_pstart .and. t_ref2m(p) < phen_tb) then 
                 sp_dayl_temp(p) = sp_dayl_temp(p) + (phen_tb - t_ref2m(p))**2 * (1.0_r8 -dayl(g)/phen_pstart)**2
               end if
             
               if (ws_flag == 1._r8) then   !Onset period
                 !Set offset counters to zero
                 sp_offset_day(p) = 0._r8
                 sp_dayl_temp(p)  = 0._r8
                 if (spring_threshold == 1) then  
                   sp_onset_day(p) = min(sp_onset_day(p)+fracday, ndays_on)
                   tlai(p) = tlai(p) * sp_onset_day(p) / ndays_on
                 else
                   tlai(p) = 0._r8
                 end if
               else                         !Offset period
                 !set onset counters to zero
                 sp_chil(p)       = 0._r8
                 sp_onset_day(p)  = 0._r8
                 sp_gdd(p)        = 0._r8
                 autumn_threshold = 0
                 !default senescence model
                 if (phen_autumn == 0 .and. dayl(g) .lt. crit_dayl) autumn_threshold = 1
                 !WM
                 if (phen_autumn == 1 .and. ((dayl(g) .lt. crit_dayl .and. t_soisno(c,3) < phen_tb) .or. &
                       t_soisno(c,3) < phen_tc)) then
                   autumn_threshold = 1
                 end if
                 !DM
                 if (phen_autumn == 2 .and. sp_dayl_temp(p) > phen_ycrit) autumn_threshold = 1
                 if (autumn_threshold == 1) then 
                   sp_offset_day(p) = sp_offset_day(p)+fracday
                 end if
                 tlai(p) = max(tlai(p) * (ndays_off - sp_offset_day(p)) / ndays_off, 0._r8)
               end if
               if (p == 4 .and. sp_offset_day(p) .gt. 0 .and. sp_offset_day(p) .lt. 0.5) print*, p, dayl(g), t_ref2m(p), tlai(p), sp_gdd(p), sp_dayl_temp(p)
            end if
 
            !-------------Stress deciduous phenology ------------------------
            if (.not. use_cn .and. stress_decid(ivt(p)) == 1._r8) then
              tlai(p) = 2.0_r8 !maxval(annlai(:,p))
              crit_dayl = 36000._r8
              if (dayl(g) .ge. crit_dayl) then
                sp_gdd(p) = sp_gdd(p) + max((t_soisno(c,3) - SHR_CONST_TKFRZ)*fracday, 0._r8)
                if (soilpsi(c,3) .ge. soilpsi_on)  sp_swi_on(p)  = sp_swi_on(p) + fracday
              end if
              !Stress offset day counters (only allow positive values)
              if (soilpsi(c,3) .lt. soilpsi_off) sp_swi_off(p) = sp_swi_off(p) + fracday               
              if (soilpsi(c,3) .ge. soilpsi_off .and. sp_swi_off(p) .lt. crit_offset_swi) sp_swi_off(p) = max(sp_swi_off(p) - fracday, 0._r8)
              !Adjust LAI (short term leaf mortality for dryness)
              !tlai(p) = tlai(p) * max((1.0_r8 - 0.5_r8 * sp_swi_off(p) / crit_offset_swi), 0.5_r8)

              if (t_soisno(c,3) .lt. SHR_CONST_TKFRZ) sp_fdd_off(p) = sp_fdd_off(p) + fracday
              if (t_soisno(c,3) .ge. SHR_CONST_TKFRZ .and. sp_fdd_off(p) .lt. crit_offset_fdd) sp_fdd_off(p) = max(sp_fdd_off(p) - fracday, 0._r8)
 
              !Onset/full LAI period
              if (sp_gdd(p) .ge. crit_onset_gdd .and. dayl(g) .ge. crit_dayl .and. sp_swi_on(p) .ge. &
                crit_onset_swi .and. sp_swi_off(p) .lt. crit_offset_swi) then
                  sp_onset_day(p) = min(sp_onset_day(p)+fracday, ndays_on)
                tlai(p) = tlai(p) * sp_onset_day(p) / ndays_on
                if (sp_onset_day(p) .lt. ndays_on) then 
                  sp_swi_off(p) = 0._r8   !Force offset counters to zero during onset period
                  sp_fdd_off(p) = 0._r8
                end if
              !Offset period
              else if (sp_gdd(p) .ge. crit_onset_gdd .and. sp_swi_on(p) .ge. crit_onset_swi .and. &
                     (dayl(g) .lt. crit_dayl .or. sp_swi_off(p) .ge. crit_offset_swi .or. &
                     sp_fdd_off(p) .ge. crit_offset_fdd)) then 
                sp_offset_day(p) = sp_offset_day(p)+fracday
                tlai(p) = tlai(p) * (ndays_off - sp_offset_day(p)) / ndays_off
              else
                tlai(p) = 0._r8
              end if
              !reset all counters when full senescence occurs
              if (sp_offset_day(p) .gt. ndays_off) then
                sp_offset_day(p) = 0._r8
                sp_onset_day(p)  = 0._r8
                sp_gdd(p)        = 0._r8
                sp_swi_on(p)     = 0._r8
                sp_swi_off(p)    = 0._r8
                sp_fdd_off(p)    = 0._r8
              end if
           endif
#endif
         endif

         tsai(p) = timwt(1)*msai2t(p,1) + timwt(2)*msai2t(p,2)
         htop(p) = timwt(1)*mhvt2t(p,1) + timwt(2)*mhvt2t(p,2)
         hbot(p) = timwt(1)*mhvb2t(p,1) + timwt(2)*mhvb2t(p,2)

         ! adjust lai and sai for burying by snow. if exposed lai and sai
         ! are less than 0.05, set equal to zero to prevent numerical
         ! problems associated with very small lai and sai.

         ! snow burial fraction for short vegetation (e.g. grasses) as in
         ! Wang and Zeng, 2007. 

         if (veg_pp%itype(p) > noveg .and. veg_pp%itype(p) <= nbrdlf_dcd_brl_shrub ) then
            ol = min( max(snow_depth(c)-hbot(p), 0._r8), htop(p)-hbot(p))
            fb = 1._r8 - ol / max(1.e-06_r8, htop(p)-hbot(p))
         else
            fb = 1._r8 - max(min(snow_depth(c),0.2_r8),0._r8)/0.2_r8   ! 0.2m is assumed
            !depth of snow required for complete burial of grasses
         endif

         ! area weight by snow covered fraction

         elai(p) = max(tlai(p)*(1.0_r8 - frac_sno(c)) + tlai(p)*fb*frac_sno(c), 0.0_r8)
         esai(p) = max(tsai(p)*(1.0_r8 - frac_sno(c)) + tsai(p)*fb*frac_sno(c), 0.0_r8)
         if (elai(p) < 0.05_r8) elai(p) = 0._r8
         if (esai(p) < 0.05_r8) esai(p) = 0._r8

         ! Fraction of vegetation free of snow

         if ((elai(p) + esai(p)) >= 0.05_r8) then
            frac_veg_nosno_alb(p) = 1
         else
            frac_veg_nosno_alb(p) = 0
         end if

      end do ! end of patch loop

    end associate

  end subroutine SatellitePhenology

  !-----------------------------------------------------------------------
  subroutine interpMonthlyVeg (bounds, canopystate_vars)
    !
    ! !DESCRIPTION:
    ! Determine if 2 new months of data are to be read.
    !
    ! !USES:
    use clm_varctl      , only : fsurdat
    use clm_time_manager, only : get_curr_date, get_step_size, get_nstep
    !
    ! !ARGUMENTS:
    type(bounds_type), intent(in) :: bounds  
    type(canopystate_type), intent(inout) :: canopystate_vars
    !
    ! !LOCAL VARIABLES:
    integer :: kyr         ! year (0, ...) for nstep+1
    integer :: kmo         ! month (1, ..., 12)
    integer :: kda         ! day of month (1, ..., 31)
    integer :: ksec        ! seconds into current date for nstep+1
    real(r8):: dtime       ! land model time step (sec)
    real(r8):: t           ! a fraction: kda/ndaypm
    integer :: it(2)       ! month 1 and month 2 (step 1)
    integer :: months(2)   ! months to be interpolated (1 to 12)
    integer, dimension(12) :: ndaypm= &
         (/31,28,31,30,31,30,31,31,30,31,30,31/) !days per month
    !-----------------------------------------------------------------------

    dtime = get_step_size()

    call get_curr_date(kyr, kmo, kda, ksec, offset=int(dtime))

    t = (kda-0.5_r8) / ndaypm(kmo)
    it(1) = t + 0.5_r8
    it(2) = it(1) + 1
    months(1) = kmo + it(1) - 1
    months(2) = kmo + it(2) - 1
    if (months(1) <  1) months(1) = 12
    if (months(2) > 12) months(2) = 1
    timwt(1) = (it(1)+0.5_r8) - t
    timwt(2) = 1._r8-timwt(1)

    if (InterpMonths1 /= months(1)) then
       if (masterproc) then
          write(iulog,*) 'Attempting to read monthly vegetation data .....'
          write(iulog,*) 'nstep = ',get_nstep(),' month = ',kmo,' day = ',kda
       end if
       call t_startf('readMonthlyVeg')
       call readMonthlyVegetation (bounds, fsurdat, months, canopystate_vars)
       InterpMonths1 = months(1)
       call t_stopf('readMonthlyVeg')
    end if

  end subroutine interpMonthlyVeg

  !-----------------------------------------------------------------------
  subroutine readAnnualVegetation (bounds, canopystate_vars)
    !
    ! !DESCRIPTION:
    ! read 12 months of veg data for dry deposition
    !
    ! !USES:
    use clm_varpar  , only : numpft
    use pftvarcon   , only : noveg
    use domainMod   , only : ldomain
    use fileutils   , only : getfil
    use clm_varctl  , only : fsurdat
    use shr_scam_mod, only : shr_scam_getCloseLatLon
    !
    ! !ARGUMENTS:
    type(bounds_type), intent(in) :: bounds  
    type(canopystate_type), intent(inout) :: canopystate_vars
    !
    ! !LOCAL VARIABLES:
    type(file_desc_t) :: ncid             ! netcdf id
    real(r8), pointer :: annlai(:,:)      ! 12 months of monthly lai from input data set 
    real(r8), pointer :: mlai(:,:)        ! lai read from input files
    real(r8):: closelat,closelon          ! single column vars
    integer :: ier                        ! error code
    integer :: g,k,l,m,n,p                ! indices
    integer :: ni,nj,ns                   ! indices
    integer :: dimid,varid                ! input netCDF id's
    integer :: ntim                       ! number of input data time samples
    integer :: nlon_i                     ! number of input data longitudes
    integer :: nlat_i                     ! number of input data latitudes
    integer :: npft_i                     ! number of input data pft types
    integer :: closelatidx,closelonidx    ! single column vars
    logical :: isgrid2d                   ! true => file is 2d
    character(len=256) :: locfn           ! local file name
    character(len=32) :: subname = 'readAnnualVegetation'
    !-----------------------------------------------------------------------

    annlai    => canopystate_vars%annlai_patch 

    ! Determine necessary indices

    allocate(mlai(bounds%begg:bounds%endg,0:numpft), stat=ier)
    if (ier /= 0) then
       write(iulog,*)subname, 'allocation error ' 
       call endrun(msg=errMsg(__FILE__, __LINE__))
    end if

    if (masterproc) then
       write (iulog,*) 'Attempting to read annual vegetation data .....'
    end if

    call getfil(fsurdat, locfn, 0)
    call ncd_pio_openfile (ncid, trim(locfn), 0)
    call ncd_inqfdims (ncid, isgrid2d, ni, nj, ns)

    if (ldomain%ns /= ns .or. ldomain%ni /= ni .or. ldomain%nj /= nj) then
       write(iulog,*)trim(subname), 'ldomain and input file do not match dims '
       write(iulog,*)trim(subname), 'ldomain%ni,ni,= ',ldomain%ni,ni
       write(iulog,*)trim(subname), 'ldomain%nj,nj,= ',ldomain%nj,nj
       write(iulog,*)trim(subname), 'ldomain%ns,ns,= ',ldomain%ns,ns
       call endrun(msg=errMsg(__FILE__, __LINE__))
    end if
    call check_dim(ncid, 'lsmpft', numpft+1)

    if (single_column) then
       call shr_scam_getCloseLatLon(locfn, scmlat, scmlon, &
            closelat, closelon, closelatidx, closelonidx)
    endif

    do k=1,12   !! loop over months and read vegetated data

       call ncd_io(ncid=ncid, varname='MONTHLY_LAI', flag='read', data=mlai, &
            dim1name=grlnd, nt=k)

       !! only vegetated patches have nonzero values
       !! Assign lai/sai/hgtt/hgtb to the top [maxpatch_pft] patches
       !! as determined in subroutine surfrd

       do p = bounds%begp,bounds%endp
          g =veg_pp%gridcell(p)
          if (veg_pp%itype(p) /= noveg) then     !! vegetated pft
             do l = 0, numpft
                if (l == veg_pp%itype(p)) then
                   annlai(k,p) = mlai(g,l)
                end if
             end do
          else                       !! non-vegetated pft
             annlai(k,p) = 0._r8
          end if
       end do   ! end of loop over patches  

    enddo ! months loop

    call ncd_pio_closefile(ncid)

    deallocate(mlai)

  endsubroutine readAnnualVegetation

  !-----------------------------------------------------------------------
  subroutine readMonthlyVegetation (bounds, &
       fveg, months, canopystate_vars)
    !
    ! !DESCRIPTION:
    ! Read monthly vegetation data for two consec. months.
    !
    ! !USES:
    use clm_varpar       , only : numpft
    use pftvarcon        , only : noveg
    use fileutils        , only : getfil
    use spmdMod          , only : masterproc, mpicom, MPI_REAL8, MPI_INTEGER
    use shr_scam_mod     , only : shr_scam_getCloseLatLon
    use clm_time_manager , only : get_nstep
    use netcdf
    !
    ! !ARGUMENTS:
    type(bounds_type) , intent(in) :: bounds  
    character(len=*)  , intent(in) :: fveg      ! file with monthly vegetation data
    integer           , intent(in) :: months(2) ! months to be interpolated (1 to 12)
    type(canopystate_type), intent(inout) :: canopystate_vars
    !
    ! !LOCAL VARIABLES:
    character(len=256) :: locfn           ! local file name
    type(file_desc_t)  :: ncid            ! netcdf id
    integer :: g,n,k,l,m,p,ni,nj,ns       ! indices
    integer :: dimid,varid                ! input netCDF id's
    integer :: ntim                       ! number of input data time samples
    integer :: nlon_i                     ! number of input data longitudes
    integer :: nlat_i                     ! number of input data latitudes
    integer :: npft_i                     ! number of input data pft types
    integer :: ier                        ! error code
    integer :: closelatidx,closelonidx
    real(r8):: closelat,closelon
    logical :: readvar
    real(r8), pointer :: mlai(:,:)        ! lai read from input files
    real(r8), pointer :: msai(:,:)        ! sai read from input files
    real(r8), pointer :: mhgtt(:,:)       ! top vegetation height
    real(r8), pointer :: mhgtb(:,:)       ! bottom vegetation height
    character(len=32) :: subname = 'readMonthlyVegetation'
    !-----------------------------------------------------------------------

    ! Determine necessary indices

    allocate(&
         mlai(bounds%begg:bounds%endg,0:numpft), &
         msai(bounds%begg:bounds%endg,0:numpft), &
         mhgtt(bounds%begg:bounds%endg,0:numpft), &
         mhgtb(bounds%begg:bounds%endg,0:numpft), &
         stat=ier)
    if (ier /= 0) then
       write(iulog,*)subname, 'allocation big error '
       call endrun(msg=errMsg(__FILE__, __LINE__))
    end if

    ! ----------------------------------------------------------------------
    ! Open monthly vegetation file
    ! Read data and convert from gridcell to pft data
    ! ----------------------------------------------------------------------

    call getfil(fveg, locfn, 0)
    call ncd_pio_openfile (ncid, trim(locfn), 0)

    if (single_column) then
       call shr_scam_getCloseLatLon (ncid, scmlat, scmlon, closelat, closelon,&
            closelatidx, closelonidx)
    endif

    do k=1,2   !loop over months and read vegetated data

       call ncd_io(ncid=ncid, varname='MONTHLY_LAI', flag='read', data=mlai, dim1name=grlnd, &
            nt=months(k), readvar=readvar)
       if (.not. readvar) call endrun(msg=' ERROR: MONTHLY_LAI NOT on fveg file'//errMsg(__FILE__, __LINE__))

       call ncd_io(ncid=ncid, varname='MONTHLY_SAI', flag='read', data=msai, dim1name=grlnd, &
            nt=months(k), readvar=readvar)
       if (.not. readvar) call endrun(msg=' ERROR: MONTHLY_SAI NOT on fveg file'//errMsg(__FILE__, __LINE__))

       call ncd_io(ncid=ncid, varname='MONTHLY_HEIGHT_TOP', flag='read', data=mhgtt, dim1name=grlnd, &
            nt=months(k), readvar=readvar)
       if (.not. readvar) call endrun(msg=' ERROR: MONTHLY_HEIGHT_TOP NOT on fveg file'//errMsg(__FILE__, __LINE__))

       call ncd_io(ncid=ncid, varname='MONTHLY_HEIGHT_BOT', flag='read', data=mhgtb, dim1name=grlnd, &
            nt=months(k), readvar=readvar)
       if (.not. readvar) call endrun(msg=' ERROR: MONTHLY_HEIGHT_TOP NOT on fveg file'//errMsg(__FILE__, __LINE__))

       ! Only vegetated patches have nonzero values
       ! Assign lai/sai/hgtt/hgtb to the top [maxpatch_pft] patches
       ! as determined in subroutine surfrd

       do p = bounds%begp,bounds%endp
          g =veg_pp%gridcell(p)
          if (veg_pp%itype(p) /= noveg) then     ! vegetated pft
             do l = 0, numpft
                if (l == veg_pp%itype(p)) then
                   mlai2t(p,k) = mlai(g,l)
                   msai2t(p,k) = msai(g,l)
                   mhvt2t(p,k) = mhgtt(g,l)
                   mhvb2t(p,k) = mhgtb(g,l)
                end if
             end do
          else                        ! non-vegetated pft
             mlai2t(p,k) = 0._r8
             msai2t(p,k) = 0._r8
             mhvt2t(p,k) = 0._r8
             mhvb2t(p,k) = 0._r8
          end if
       end do   ! end of loop over patches

    end do   ! end of loop over months

    call ncd_pio_closefile(ncid)

    if (masterproc) then
       k = 2
       write(iulog,*) 'Successfully read monthly vegetation data for'
       write(iulog,*) 'month ', months(k)
       write(iulog,*)
    end if

    deallocate(mlai, msai, mhgtt, mhgtb)

    do p = bounds%begp,bounds%endp
       canopystate_vars%mlaidiff_patch(p) = mlai2t(p,1)-mlai2t(p,2)
    enddo

  end subroutine readMonthlyVegetation

end module SatellitePhenologyMod
