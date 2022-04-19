SUPPORTS_CXX := FALSE
ifeq ($(COMPILER),gnu)
  SUPPORTS_CXX := TRUE
  CFLAGS :=  -mcmodel=medium 
  CXX_LINKER := FORTRAN
  FC_AUTO_R8 :=  -fdefault-real-8 
  FFLAGS :=  -mcmodel=medium -fconvert=big-endian -ffree-line-length-none -ffixed-line-length-none 
  FFLAGS_NOOPT :=  -O0 
  FIXEDFLAGS :=   -ffixed-form 
  FREEFLAGS :=  -ffree-form 
  HAS_F2008_CONTIGUOUS := FALSE
  MPICC :=  mpicc  
  MPICXX :=  mpicxx 
  MPIFC :=  mpif90 
  SCC :=  gcc 
  SCXX :=  g++ 
  SFC :=  gfortran 
endif
ifeq ($(COMPILER),intel)
  SUPPORTS_CXX := TRUE
  CFLAGS :=  -O2 -fp-model precise -std=gnu99 
  CXX_LINKER := FORTRAN
  FC_AUTO_R8 :=  -r8 
  FFLAGS :=   -convert big_endian -assume byterecl -ftz -traceback -assume realloc_lhs -fp-model source 
  FFLAGS_NOOPT :=  -O0 
  FIXEDFLAGS :=  -fixed -132 
  FREEFLAGS :=  -free 
  HAS_F2008_CONTIGUOUS := TRUE
  MPICC :=  mpicc  
  MPICXX :=  mpicxx 
  MPIFC :=  mpif90 
  SCC :=  icc 
  SCXX :=  icpc 
  SFC :=  ifort 
  CXXFLAGS :=  -std=c++11 -fp-model source 
  CXX_LDFLAGS :=  -cxxlib 
endif
ifeq ($(COMPILER),intel)
  NETCDF_PATH := /sw/cs400_centos7.3_acfsoftware/netcdf/4.4.1.1/centos7.3_intel17.2.174/
endif
ifeq ($(MODEL),ice)
  CPPDEFS := $(CPPDEFS)  -DUSE_PIO2  -DCPL_BYPASS
endif
ifeq ($(MODEL),ocn)
  CPPDEFS := $(CPPDEFS)  -DUSE_PIO2  -DCPL_BYPASS
endif
ifeq ($(MODEL),glc)
  CPPDEFS := $(CPPDEFS)  -DUSE_PIO2  -DCPL_BYPASS
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
    CFLAGS := $(CFLAGS)  -g -Wall -Og -fbacktrace -fcheck=bounds -ffpe-trap=invalid,zero,overflow
    FFLAGS := $(FFLAGS)  -g -Wall -Og -fbacktrace -fcheck=bounds -ffpe-trap=invalid,zero,overflow
  endif
  ifeq ($(DEBUG),FALSE)
    CFLAGS := $(CFLAGS)  -O 
    FFLAGS := $(FFLAGS)  -O 
  endif
  ifeq ($(MODEL),cism)
    CMAKE_OPTS := $(CMAKE_OPTS)  -D CISM_GNU=ON 
  endif
  ifeq ($(compile_threaded),TRUE)
    LDFLAGS := $(LDFLAGS)  -fopenmp 
  endif
endif
ifeq ($(COMPILER),intel)
  CPPDEFS := $(CPPDEFS)  -DFORTRANUNDERSCORE -DNO_R16 -DCPRINTEL -DCPL_BYPASS
  SLIBS := $(SLIBS) -L/sw/cs400_centos7.3_acfsoftware/lapack/3.7.0/centos7.3_gnu6.3.0/lib -llapack -lblas -L/sw/cs400_centos7.3_acfsoftware/netcdf/4.4.1.1/centos7.3_intel17.2.174/lib -lnetcdff -lnetcdf -lgfortran
  ifeq ($(compile_threaded),TRUE)
    CFLAGS := $(CFLAGS)  -qopenmp 
    FFLAGS := $(FFLAGS)  -qopenmp 
    CXXFLAGS := $(CXXFLAGS)  -qopenmp 
  endif
  ifeq ($(DEBUG),FALSE)
    CFLAGS := $(CFLAGS)  -O2 -debug minimal 
    FFLAGS := $(FFLAGS)  -O2 -debug minimal 
    CXXFLAGS := $(CXXFLAGS)  -O2 
  endif
  ifeq ($(DEBUG),TRUE)
    CFLAGS := $(CFLAGS)  -O0 -g 
    FFLAGS := $(FFLAGS)  -O0 -g -check uninit -check bounds -check pointers -fpe0 -check noarg_temp_created 
    CXXFLAGS := $(CXXFLAGS)  -O0 -g 
  endif
  ifeq ($(compile_threaded),TRUE)
    LDFLAGS := $(LDFLAGS)  -qopenmp 
  endif
endif
