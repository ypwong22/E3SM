#!/bin/bash -e

# Batch system directives
#PBS  -N run.20220407_stopdate365_switch3_plot16_US-SPR_ICB20TRCNPRDCTCBC
#PBS  -r n 
#PBS  -j oe 
#PBS  -V 
#PBS -l nodes=2:ppn=1
#PBS -l partition=beacon

# template to create a case run shell script. This should only ever be called
# by case.submit when on batch. Use case.submit from the command line to run your case.

# cd to case
cd /nics/c/home/ywang254/models/E3SM/cime/scripts/20220407_stopdate365_switch3_plot16_US-SPR_ICB20TRCNPRDCTCBC

# Set PYTHONPATH so we can make cime calls if needed
LIBDIR=/nics/c/home/ywang254/models/E3SM/cime/scripts/lib
export PYTHONPATH=$LIBDIR:$PYTHONPATH

# get new lid
lid=$(python -c 'import CIME.utils; print CIME.utils.new_lid()')
export LID=$lid

# setup environment
source .env_mach_specific.sh

# Clean/make timing dirs
RUNDIR=$(./xmlquery RUNDIR --value)
if [ -e $RUNDIR/timing ]; then
    /bin/rm $RUNDIR/timing
fi
mkdir -p $RUNDIR/timing/checkpoints

# minimum namelist action
./preview_namelists --component cpl
#./preview_namelists # uncomment for full namelist generation

# uncomment for lockfile checking
# ./check_lockedfiles

# setup OMP_NUM_THREADS
export OMP_NUM_THREADS=$(./xmlquery THREAD_COUNT --value)

# save prerun provenance?

# MPIRUN!
cd $(./xmlquery RUNDIR --value)
   /lustre/haven/user/ywang254/E3SM/output/20220407_stopdate365_switch3_US-SPR_ICB1850CNRDCTCBC_ad_spinup/bld/e3sm.exe   >> e3sm.log.$LID 2>&1 

# save logs?

# save postrun provenance?

# resubmit ?
