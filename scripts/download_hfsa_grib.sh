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


while (( cycles < infinity )) && ! download_hfsa_grib ; do
    echo "Waiting for HFSA files at" $( date )
    cycles=$(( cycles + 1 ))
    sleep "$naptime"
done

if (( cycles >= infinity )) ; then
    echo "Waited too long for HFSA files. Giving up."
    exit 1
else
    echo "Downloaded HFSA data."
fi
