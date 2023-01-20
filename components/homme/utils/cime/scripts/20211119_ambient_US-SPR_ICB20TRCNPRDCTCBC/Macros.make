SUPPORTS_CXX := FALSE
ifeq ($(COMPILER),intel)
  MPIFC :=  mpif90 
  FFLAGS_NOOPT :=  -O0 
  CXXFLAGS :=  -std=c++11 -fp-model source 
  MPICC :=  mpicc  
  SCC :=  icc 
  MPICXX :=  mpicxx 
  HAS_F2008_CONTIGUOUS := TRUE
  CXX_LDFLAGS :=  -cxxlib 
  SUPPORTS_CXX := TRUE
  FFLAGS :=   -convert big_endian -assume byterecl -ftz -traceback -assume realloc_lhs -fp-model source 
  FIXEDFLAGS :=  -fixed -132 
  CXX_LINKER := FORTRAN
  FC_AUTO_R8 :=  -r8 
  CFLAGS :=  -O2 -fp-model precise -std=gnu99 
  FREEFLAGS :=  -free 
  SFC :=  ifort 
  SCXX :=  icpc 
endif
ifeq ($(COMPILER),gnu)
  MPIFC :=  mpif90 
  FFLAGS_NOOPT :=  -O0 
  MPICC :=  mpicc  
  SCC :=  gcc 
  MPICXX :=  mpicxx 
  HAS_F2008_CONTIGUOUS := FALSE
  SUPPORTS_CXX := TRUE
  FFLAGS :=  -mcmodel=medium -fconvert=big-endian -ffree-line-length-none -ffixed-line-length-none 
  FIXEDFLAGS :=   -ffixed-form 
  CXX_LINKER := FORTRAN
  FC_AUTO_R8 :=  -fdefault-real-8 
  CFLAGS :=  -mcmodel=medium 
  FREEFLAGS :=  -ffree-form 
  SFC :=  gfortran 
  SCXX :=  g++ 
endif
ifeq ($(COMPILER),intel)
  NETCDF_PATH := /sw/cs400_centos7.3_acfsoftware/netcdf/4.4.1.1/centos7.3_intel17.2.174/
endif
ifeq ($(MODEL),glc)
  CPPDEFS := $(CPPDEFS)  -DUSE_PIO2  -DCPL_BYPASS
endif
ifeq ($(MODEL),ice)
  CPPDEFS := $(CPPDEFS)  -DUSE_PIO2  -DCPL_BYPASS
endif
ifeq ($(MODEL),ocn)
  CPPDEFS := $(CPPDEFS)  -DUSE_PIO2  -DCPL_BYPASS
endif
ifeq ($(COMPILER),intel)
  SLIBS := $(SLIBS) -L/sw/cs400_centos7.3_acfsoftware/lapack/3.7.0/centos7.3_gnu6.3.0/lib -llapack -lblas -L/sw/cs400_centos7.3_acfsoftware/netcdf/4.4.1.1/centos7.3_intel17.2.174/lib -lnetcdff -lnetcdf -lgfortran
  CPPDEFS := $(CPPDEFS)  -DFORTRANUNDERSCORE -DNO_R16 -DCPRINTEL -DCPL_BYPASS
  ifeq ($(compile_threaded),TRUE)
    CXXFLAGS := $(CXXFLAGS)  -qopenmp 
    FFLAGS := $(FFLAGS)  -qopenmp 
    CFLAGS := $(CFLAGS)  -qopenmp 
  endif
  ifeq ($(DEBUG),TRUE)
    CXXFLAGS := $(CXXFLAGS)  -O0 -g 
    FFLAGS := $(FFLAGS)  -O0 -g -check uninit -check bounds -check pointers -fpe0 -check noarg_temp_created 
    CFLAGS := $(CFLAGS)  -O0 -g 
  endif
  ifeq ($(DEBUG),FALSE)
    CXXFLAGS := $(CXXFLAGS)  -O2 
    FFLAGS := $(FFLAGS)  -O2 -debug minimal 
    CFLAGS := $(CFLAGS)  -O2 -debug minimal 
  endif
  ifeq ($(compile_threaded),TRUE)
    LDFLAGS := $(LDFLAGS)  -qopenmp 
  endif
endif
ifeq ($(COMPILER),gnu)
  CPPDEFS := $(CPPDEFS)  -DFORTRANUNDERSCORE -DNO_R16 -DCPRGNU -DCPL_BYPASS
  ifeq ($(compile_threaded),TRUE)
    CFLAGS := $(CFLAGS)  -fopenmp 
  endif
  ifeq ($(MODEL),csm_share)
    CFLAGS := $(CFLAGS)  -std=c99 
  endif
  ifeq ($(compile_threaded),TRUE)
    FFLAGS := $(FFLAGS)  -fopenmp 
  endif
  ifeq ($(DEBUG),TRUE)
    FFLAGS := $(FFLAGS)  -g -Wall -Og -fbacktrace -fcheck=bounds -ffpe-trap=invalid,zero,overflow
    CFLAGS := $(CFLAGS)  -g -Wall -Og -fbacktrace -fcheck=bounds -ffpe-trap=invalid,zero,overflow
  endif
  ifeq ($(DEBUG),FALSE)
    FFLAGS := $(FFLAGS)  -O 
    CFLAGS := $(CFLAGS)  -O 
  endif
  ifeq ($(MODEL),cism)
    CMAKE_OPTS := $(CMAKE_OPTS)  -D CISM_GNU=ON 
  endif
  ifeq ($(compile_threaded),TRUE)
    LDFLAGS := $(LDFLAGS)  -fopenmp 
  endif
endif
