#!/bin/bash -e

# Batch system directives
#SBATCH  --job-name=run.UQ_root_US-SPR_ICB1850CNRDCTCBC_ad_spinup
#SBATCH  --nodes=1
#SBATCH  --output=run.UQ_root_US-SPR_ICB1850CNRDCTCBC_ad_spinup.%j 
#SBATCH  --exclusive 

# template to create a case run shell script. This should only ever be called
# by case.submit when on batch. Use case.submit from the command line to run your case.

# cd to case
cd /home/ywo/models/E3SM/cime/scripts/UQ_root_US-SPR_ICB1850CNRDCTCBC_ad_spinup

# Set PYTHONPATH so we can make cime calls if needed
LIBDIR=/home/ywo/models/E3SM/cime/scripts/lib
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
   /lustre/or-scratch/cades-ccsi/scratch/ywo/E3SM/output/UQ_root_US-SPR_ICB1850CNRDCTCBC_ad_spinup/bld/e3sm.exe   >> e3sm.log.$LID 2>&1 

# save logs?

# save postrun provenance?

# resubmit ?