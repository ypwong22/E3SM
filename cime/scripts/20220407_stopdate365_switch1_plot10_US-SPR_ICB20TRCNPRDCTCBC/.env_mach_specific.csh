# This file is for user convenience only and is not used by the model
# Changes to this file will be ignored and overwritten
# Changes to the environment should be made in env_mach_specific.xml
# Run ./case.setup --reset to regenerate this file
source /usr/share/Modules/init/csh
module purge 
module load PE-intel mkl/2017 cmake/3.17.3 nco/4.6.6 hdf5-parallel/1.10.1 netcdf/4.4.1.1 perl/5.24.1
setenv PERL5LIB /nics/c/home/ywang254/perl5/lib/perl5:/opt/moab/lib/perl5:/sw/cs400_centos7.3_acfsoftware/perl/5.24.1/centos7.3_gnu6.3.0/lib/5.24.1/