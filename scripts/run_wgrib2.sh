#!/bin/bash

set -x -u -e -o pipefail

source "$INSTALLDIR/parm/paths.sh"
source "$INSTALLDIR/scripts/grabNpost.sh"

set +x
load_modules write
set -x

set_vars_for_cycle "$ATIME" "$WORKDIR" "$OUTDIR" "$INSTALLDIR"
cd "$workdir" # workdir is set in set_vars_for_cycle to $WORKDIR

ulimit -s unlimited

link_downloaded_files
wgrib2_inventory
wgrib2_make_cmdfile
wgrib2_run_cmdfile
combine_files

echo normal completion
