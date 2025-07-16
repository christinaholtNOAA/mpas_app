#!/bin/bash

set -x -u -e -o pipefail

stdout="$OUTDIR/chosen_storm.txt"
stderr="$OUTDIR/chosen_storm_reasoning.txt"

"$INSTALLDIR/scripts/choose_storm.sh" "$OUTDIR/message" "$OUTDIR/merged-by-field" "$ATIME" > "$stdout" 2> "$stderr"

if [[ -s "$stdout" ]] ; then
    set +x
    echo chosen storm is in "$stdout"
    echo reasoning is in "$stderr"
    echo normal completion
else
    echo unexpected error while choosing a storm
    echo storm choice file is empty: "$stdout"
    echo stderr contained:
    cat "$stderr" 1>&2
    exit 1
fi
