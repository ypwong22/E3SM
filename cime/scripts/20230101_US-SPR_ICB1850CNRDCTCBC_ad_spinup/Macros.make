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
  FFLAGS_NOOPT :=  -O0 
  HAS_F2008_CONTIGUOUS := FALSE
  CFLAGS :=  -mcmodel=medium 
endif
ifeq ($(COMPILER),gnu)
  MPIFC := mpif90
  MPICC := mpicc
  LAPACK_LIBDIR := /software/tools/compilers/intel_2017/mkl/lib/intel64
  PNETCDF_PATH := /software/dev_tools/swtree/cs400_centos7.2_pe2016-08/pnetcdf/1.9.0/centos7.2_gnu5.3.0
  SCC := gcc
  NETCDF_C_PATH := /software/dev_tools/swtree/cs400_centos7.2_pe2016-08/netcdf/4.3.3.1/centos7.2_gnu5.3.0
  MPICXX := mpic++
  NETCDF_PATH := /software/dev_tools/swtree/cs400_centos7.2_pe2016-08/netcdf-hdf5parallel/4.3.3.1/centos7.2_gnu5.3.0
  SUPPORTS_CXX := TRUE
  FFLAGS :=  -O -fconvert=big-endian -ffree-line-length-none -ffixed-line-length-none -fno-range-check
  FIXEDFLAGS :=   -ffixed-form 
  HDF5_PATH := /software/dev_tools/swtree/cs400_centos7.2_pe2016-08/hdf5-parallel/1.10.6/centos7.5_gnu8.1.0
  CXX_LINKER := FORTRAN
  FC_AUTO_R8 :=  -fdefault-real-8 
  NETCDF_FORTRAN_PATH := /software/dev_tools/swtree/cs400_centos7.2_pe2016-08/netcdf/4.3.3.1/centos7.2_gnu5.3.0
  FREEFLAGS :=  -ffree-form 
  SFC := gfortran
  SCXX := g++
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
endif
ifeq ($(COMPILER),gnu)
  CPPDEFS := $(CPPDEFS)  -DFORTRANUNDERSCORE -DNO_R16 -DCPRGNU -DCPL_BYPASS
  CPPDEFS := $(CPPDEFS)  -DFORTRANUNDERSCORE -DNO_R16 -DCPL_BYPASS
  ifeq ($(compile_threaded),TRUE)
    CFLAGS := $(CFLAGS)  -fopenmp 
    CFLAGS := $(CFLAGS)  -fopenmp 
  endif
  ifeq ($(MODEL),csm_share)
    CFLAGS := $(CFLAGS)  -std=c99 
  endif
  ifeq ($(compile_threaded),TRUE)
    FFLAGS := $(FFLAGS)  -fopenmp 
    FFLAGS := $(FFLAGS)  -fopenmp 
  endif
  ifeq ($(DEBUG),TRUE)
    FFLAGS := $(FFLAGS)  -g -Wall -Og -fbacktrace -fcheck=bounds -ffpe-trap=invalid,zero,overflow
    FFLAGS := $(FFLAGS)  -g -Wall 
    CFLAGS := $(CFLAGS)  -g -Wall -Og -fbacktrace -fcheck=bounds -ffpe-trap=invalid,zero,overflow
  endif
  ifeq ($(DEBUG),FALSE)
    FFLAGS := $(FFLAGS)  -O 
    CFLAGS := $(CFLAGS)  -O 
  endif
  ifeq ($(MODEL),cism)
    CMAKE_OPTS := $(CMAKE_OPTS)  -D CISM_GNU=ON 
    CMAKE_OPTS := $(CMAKE_OPTS)  -D CISM_GNU=ON 
  endif
endif
ifeq ($(COMPILER),intel)
  ifeq ($(compile_threaded),TRUE)
    LDFLAGS := $(LDFLAGS)  -qopenmp 
  endif
endif
ifeq ($(COMPILER),gnu)
  ifeq ($(compile_threaded),TRUE)
    LDFLAGS := $(LDFLAGS)  -fopenmp 
    LDFLAGS := $(LDFLAGS)  -fopenmp 
  endif
  ifeq ($(MODEL),driver)
    LDFLAGS := $(LDFLAGS)  -L$(NETCDF_PATH)/lib -Wl,-rpath=$(NETCDF_PATH)/lib -lnetcdff -lnetcdf 
  endif
endif
