# This file is for user convenience only and is not used by the model
# Changes to this file will be ignored and overwritten
# Changes to the environment should be made in env_mach_specific.xml
# Run ./case.setup --reset to regenerate this file
source /usr/share/Modules/init/sh
module purge 
module load PE-gnu perl mkl/2018.1.163 cmake/3.20.3 openmpi/3.0.0 python/3.6.3 hdf5-parallel/1.10.6 netcdf/4.3.3.1 pnetcdf/1.9.0
export PERL5LIB=/software/user_tools/current/cades-ccsi/perl5/lib/perl5/