#! /bin/bash

source "$INSTALLDIR/parm/paths.sh"
source "$INSTALLDIR/scripts/grabNpost.sh"

set -xue -o pipefail

load_modules
set_vars_for_cycle "$ATIME" "$WORKDIR" "$OUTDIR" "$INSTALLDIR"

export TZ=UTC

naptime=120 # seconds
infinity=100 # infinite loop guard
cycles=1

while (( cycles < infinity )) && ! ( check_for_gfs_0p25 && download_gfs_0p25 ) ; do
    echo "Waiting for GFS 0p25 files at" $( date )
    cycles=$(( cycles + 1 ))
    sleep "$naptime"
done

if (( cycles >= infinity )) ; then
    echo "Waited too long for GFS 0p25 files. Giving up."
    exit 1
else
    echo "Downloaded GFS 0p25 data."
fi
