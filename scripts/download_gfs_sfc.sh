#!/bin/bash

set -xue -o pipefail
source "$INSTALLDIR/parm/paths.sh"
source "$INSTALLDIR/scripts/grabNpost.sh"

load_modules
set_vars_for_cycle "$ATIME" "$WORKDIR" "$OUTDIR" "$INSTALLDIR"

export TZ=UTC

naptime=120 # seconds
infinity=100 # infinite loop guard
cycles=1

mkdir -p "$WORKDIR"
mkdir -p "$OUTDIR"
mkdir -p "$LOGDIR"

while (( cycles < infinity )) && ! ( check_for_gfs_sfc && download_gfs_sfc ) ; do
    echo "Waiting for GFS sfc files at" $( date )
    cycles=$(( cycles + 1 ))
    sleep "$naptime"
done

if (( cycles >= infinity )) ; then
    echo "Waited too long for GFS sfc files. Giving up."
    exit 1
else
    echo "Downloaded GFS sfc data."
fi
