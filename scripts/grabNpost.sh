#!/bin/bash

# This is a library of shell functions. It should be sourced, not executed.

load_modules() {
    local grib2_operations="${1:-no}"

    module purge
    module use "${upp_clone}/modulefiles"
    module load ursa_intelllvm

    if [[ "$grib2_operations" == read ]] ; then
        module load wgrib2/3.1.3_ncep
    elif [[ "$grib2_operations" == write ]] ; then
        module load grib-util/1.5.0
        module load wgrib2/3.6.0
    else
        : # Don't load wgrib2
    fi

    module list
}

ls_s3() {
    "${aws_cli}" s3 ls --no-sign-request "$@"
}

cp_s3() {
    "${aws_cli}" s3 cp --no-sign-request "$@"
}

set_vars_for_cycle() {
    when=${1:-2025-06-16t12:00:00}
    workdir="$2"
    outdir="$3"
    homedir="$4"

    #    YYYY-MM-DDtHH:00:00
    #    0123456789012345678

    YYYY=${when:0:4}
    MM=${when:5:2}
    DD=${when:8:2}
    HH=${when:11:2}

    syndat_plus="/scratch3/HFIP/hwrfv3/noscrub/input/SYNDAT-PLUS/syndat_tcvitals.${YYYY}"

    gfs_atm="gfs.t${HH}z.atmf000.nc"
    s3_gfs_atm="s3://noaa-gfs-bdp-pds/gfs.${YYYY}${MM}${DD}/${HH}/atmos/${gfs_atm}"

    gfs_sfc="gfs.t${HH}z.sfcanl.nc"
    s3_gfs_sfc="s3://noaa-gfs-bdp-pds/gfs.${YYYY}${MM}${DD}/${HH}/atmos/${gfs_sfc}"

    gfs_0p25="gfs.t${HH}z.pgrb2.0p25.f000"
    gfs_0p25b="gfs.t${HH}z.pgrb2b.0p25.f000"
    combo_0p25="gfs.t${HH}z.both.0p25.f000"
    s3_gfs_0p25="s3://noaa-gfs-bdp-pds/gfs.${YYYY}${MM}${DD}/${HH}/atmos/${gfs_0p25}"
    s3_gfs_0p25b="s3://noaa-gfs-bdp-pds/gfs.${YYYY}${MM}${DD}/${HH}/atmos/${gfs_0p25b}"

    hafs_suffix=parent.atm.f000.grb2

    hfsa_dir="s3://noaa-nws-hafs-pds/hfsa/${YYYY}${MM}${DD}/${HH}/"
    hfsa_wildcard="*${YYYY}${MM}${DD}${HH}.hfsa.*${hafs_suffix}*"

    gfs=HURPRS.GrbF00
    gfs_prefix="00x.$YYYY$MM$DD$HH.gfso"
    fix_hires="$homedir/fix/C1536-GFS-sample-HURPRS.GrbF00"
    hires="$workdir/C1536-GFS-sample-HURPRS.GrbF00"
}

download_hfsa_grib() {
    pushd "$outdir"
    cp_s3 --recursive --exclude "*" --include "$hfsa_wildcard" "$hfsa_dir" .
    popd
}

download_gfs_0p25() {
    pushd "$outdir"

    rm -f "gfs_0p25"
    rm -f "gfs_0p25b"

    cp_s3 "$s3_gfs_0p25" "$gfs_0p25"
    cp_s3 "$s3_gfs_0p25b" "$gfs_0p25b"

    popd
}

check_for_gfs_0p25() {
    set -xu
    ls_s3 "$s3_gfs_0p25" && ls_s3 "$s3_gfs_0p25b"
}

check_for_gfs_sfc() {
    ls_s3 "$s3_gfs_sfc"
}

download_gfs_sfc() {
    pushd "$outdir"

    rm -f "$gfs_sfc"
    cp_s3 "$s3_gfs_sfc" "$gfs_sfc"

    popd
}

check_for_gfs_atm() {
    ls_s3 "$s3_gfs_atm"
}

download_gfs_atm() {
    pushd "$outdir"

    rm -f "$gfs_atm"
    cp_s3 "$s3_gfs_atm" "$gfs_atm"

    popd
}

download_storm_messages() {
    pushd "$outdir"

    for id in $( seq 1 7 ) ; do
        cp_s3 "${s3_message}${id}" "message${id}"
    done

    popd
}

inventory_file() {
    local file="$1"
    local short_inventory="$2"

    srun -n 1 wgrib2 -v "$file" > "${file}.wgrib2_v"

    cat "${file}.wgrib2_v" | sed -E 's,.*d=[0-9]+:,,g' | uniq | while read record ; do
        if [[ "$record" =~ "UGRD" ]] ; then
            # Always print U and V together
            echo "$record"
            echo "$record" | sed 's,UGRD U,VGRD V,g'
        elif [[ "$record" =~ "VGRD" ]] ; then
            : # Don't double-print VGRD
        else
            echo "$record"
        fi
    done | uniq > "$short_inventory"

}

link_downloaded_files() {
    local downloaded
    local copy
    ln -sf "$outdir"/*grb2* "$outdir"/*.nc* .
    ln -sf "$fix_hires" "$hires"
    ln -sf $outdir/../preproc_upp/000/HURPRS.GrbF00 .
}

wgrib2_inventory() {
    inventory_file "$gfs" all_fields

    grep -vE 'surface|below ground|mean sea level' all_fields | grep -vE 'REFD |DPT |RH |REFC |ABSV ' > to_merge
    grep -E  'surface|below ground|mean sea level' all_fields | grep -vE 'REFD |DPT |RH |REFC |ABSV ' > to_keep

    wgrib2 -v "${hires}" > "${hires}.wgrib2_v"

    cat "$gfs_0p25" "$gfs_0p25b" > "$combo_0p25"
    wgrib2 -v "${combo_0p25}" > "${combo_0p25}.wgrib2_v"

    if ( ls -1 *parent.atm.f000.grb2 > /dev/null ) ; then
        for hafs in *parent.atm.f000.grb2 ; do
            srun -n 1 wgrib2 -v "${hafs}" > "${hafs}.wgrib2_v"
        done
    fi
}

echo_commands() {
    export start_text="pwd ; source $homedir/scripts/grabNpost.sh ; set_vars_for_cycle ${YYYY}-${MM}-${DD}t${HH}:00:00 '$workdir' '$outdir' '$homedir' ; interp_one_record"
    cat to_keep | grep -v VGRD | awk "{print \"$start_text '\" \$0 \"' to_keep\"}"
    cat to_merge | grep -v VGRD | awk "{print \"$start_text '\" \$0 \"' to_merge\"}"
    if ( ls -1 *parent.atm.f000.grb2 > /dev/null ) ; then
        local storm_cycle_type
        for hafs in *parent.atm.f000.grb2 ; do
            storm_cycle_type=$( echo "$hafs" | sed "s,.${hafs_suffix},,g" )
            cat to_merge | grep -v VGRD | awk "{print \"$start_text '\" \$0 \"' '$storm_cycle_type'\"}"
        done
    fi
}

wgrib2_make_cmdfile() {
    rm -rf "$workdir"/by-record
    rm -rf "$workdir"/by-field
    rm -rf "$workdir"/by-field-0p25

    mkdir "$workdir"/by-record
    mkdir "$workdir"/by-field
    mkdir "$workdir"/by-field-0p25

    echo_commands < /dev/null | awk '{print $0" "NR}' > cmdfile
}

decide_field() {
    # Given a wgrib2 -v line, prints out the name of the per-field file it goes in.
    local record="$1"
    if ! [[ "$record" =~ mb: ]] ; then
        # 2D and surface fields go in SFC
        field=SFC
    elif [[ "$record" =~ GRD ]] ; then
        # U and V 3D share a file
        field=UVGRD
    else
        # All other fields go in their own file
        field=$( echo "$record" | sed -E 's,.*d=[0-9]+:,,g' | sed -E 's,[ :].*,,g' )
    fi
    echo $field
}

interp_to_format() {
    local field="$1"
    local grid="$2"
    local from="$3"
    local temp="$4"
    local final="$5"

    wgrib2 "$from" -new_grid grib "$grid" unused "$temp"
    #wgrib2 -V "$temp"

    if [[ "$field" == SFC ]] ; then
        cp -fp "$temp" "$final"
    else
        cnvgrib -g22 -p40 "$temp" "$final"
        #wgrib2 -V "$final"
    fi
}

interp_two_to_format() {
    local field="$1"
    local grid="$2"
    local from_under="$3"
    local from_over="$4"
    local temp_under="$5"
    local temp_over="$6"
    local temp_combo="$7"
    local final="$8"

    wgrib2 "$from_under" -new_grid grib "$grid" unused "$temp_under"
    #wgrib2 -V "$temp_under"
    wgrib2 "$from_over" -new_grid grib "$grid" unused "$temp_over"
    #wgrib2 -V "$temp_over"
    wgrib2 "$temp_over" -rpn sto_1 -import_grib "$temp_under" -rpn "rcl_1:merge" -grib_out "$temp_combo"
    #wgrib2 -V "$temp_combo"

    if [[ "$field" == SFC ]] ; then
        cp -fp "$temp_combo" "$final"
    else
        cnvgrib -g22 -p40 "$temp_combo" "$final"
        #wgrib2 -V "$final"
    fi
}

interp_one_record() {

    #set -xue -o pipefail
    set -ue -o pipefail

    local record="$1" # one line from a wgrib2 -v dump
    local type="$2" # to_keep or to_merge or 05e.2025061818.hfsa
    local global_task_number=$3 # unique number that increments for each task and record

    local localdir=$( printf "$workdir/by-record/%05d" $global_task_number )
    local field=$( decide_field "$record" )
    local outfile=$( printf %s/%05d_%s_%s.grb2 "$workdir/by-field" "$global_task_number" "$field" "$type" )
    local out0p25=$( printf %s/%05d_%s_%s.grb2 "$workdir/by-field-0p25" "$global_task_number" "$field" "$type" )
    local record_search=$( echo "$record" | sed -E 's,^[0-9]+:[0-9]+:,,g' | sed -E 's,[(){}*.+?\[-^-],.,g' | sed -E 's,[UV]GRD [UV],.GRD .,g' )

    echo prepare "$outfile" and "$out0p25"

    rm -rf "$localdir"
    mkdir "$localdir"
    local startdir="$PWD"
    cd "$localdir"

    echo scan $hires.wgrib2_v for "$record_search"
    grep "$record_search" "$hires.wgrib2_v" | wgrib2 -i "$hires" -grib hires.grb2
    #wgrib2 -V hires.grb2

    echo scan "$hires.wgrib2_v" for "$record_search"
    grep "$record_search" "$workdir/$gfs.wgrib2_v" | wgrib2 -i "$workdir/$gfs" -grib gfs.grb2
    #wgrib2 -V gfs.grb2

    if ( grep "$record_search" "$workdir/$combo_0p25.wgrib2_v" | wgrib2 -i "$workdir/$combo_0p25" -grib 0p25.grb2 ) ; then
        local have_0p25=YES
    else
        local have_0p25=NO
        echo Missing field: gfs 0p25 file "$workdir/$combo_0p25.wgrib2_v" lacks "$record_search"
    fi
    #wgrib2 -V 0p25.grb2

    if [[ "$type" == to_keep || "$type" == to_merge ]] ; then
        interp_to_format "$field" hires.grb2 gfs.grb2 gfs-scaled.grb2 "$outfile"
        if [[ "$have_0p25" == YES ]] ; then
            interp_to_format "$field" 0p25.grb2 gfs-scaled.grb2 gfs-0p25.grb2 "$out0p25"
        fi

        echo made "$outfile" and "$out0p25" using GFS only
    else
        hafs="${workdir}/${type}.parent.atm.f000.grb2"
        if [[ -s "$hafs" ]] ; then
            grep "$record_search" "${hafs}.wgrib2_v" | wgrib2 -i "${hafs}" -grib hafs.grb2
            #wgrib2 -V hafs.grb2
            
            interp_two_to_format "$field" hires.grb2 gfs.grb2 hafs.grb2 gfs-scaled.grb2 hafs-scaled.grb2 merged.grb2 "$outfile"
            if [[ "$have_0p25" == YES ]] ; then
                interp_to_format "$field" 0p25.grb2 merged.grb2 merged-0p25.grb2 "$out0p25"
            fi

            echo made "$outfile" and "$out0p25" using GFS only
        fi
    fi

    cd "$startdir"
}

wgrib2_run_cmdfile() {
    export SCR_CMDFILE=cmdfile
    export SCR_IMMEDIATE_EXIT=no
    export SCR_PGMMODEL=MPMD
    export SCR_VERBOSITY=quiet
    srun -l "$mpiserial"
}

combine_files() {
    fields=$( sed 's,[ :].*,,g' to_merge|sort -u | grep -v GRD )
    fields="$fields UVGRD"

    if ( ls -1 "$outdir"/*parent.atm.f000.grb2 > /dev/null ) ; then
        local have_hafs=YES
    else
        local have_hafs=NO
    fi
    
    rm -rf "$outdir/merged-by-field"
    mkdir "$outdir/merged-by-field"

    cd "$workdir/by-field"

    ls -1 | grep -E 'grb2$' | sort -t _ -nk1,1 > listing

    for field in $fields ; do
        cat $( grep to_merge listing | grep "$field" ) > "$outdir/merged-by-field/${gfs_prefix}.$field.grb2"
        if [[ "$have_hafs" == YES ]] ; then
            for hafs in "$outdir"/*parent.atm.f000.grb2 ; do
                storm_cycle_type=$( basename "$hafs" | sed "s,.${hafs_suffix},,g" )
                cat $( grep "$storm_cycle_type" listing | grep "$field" ) > "$outdir/merged-by-field/${storm_cycle_type}.$field.grb2"
            done
        fi
    done

    field=SFC
    gfsfile="$outdir/merged-by-field/${gfs_prefix}.$field.grb2"
    cat $( grep to_keep listing | grep "$field" ) > "$gfsfile"
    if [[ "$have_hafs" == YES ]] ; then
        for hafs in "$outdir"/*parent.atm.f000.grb2 ; do
            storm_cycle_type=$( basename "$hafs" | sed "s,.${hafs_suffix},,g" )
            outfile="$outdir/merged-by-field/${storm_cycle_type}.$field.grb2"
            cat $( grep "$storm_cycle_type" listing | grep "$field" )  "$outdir/merged-by-field/${gfs_prefix}.$field.grb2" > "$outfile"
        done
    fi

    cd ../by-field-0p25

    ls -1 | grep -E 'grb2$' | sort -t _ -nk1,1 > listing

    cat $( grep to_keep listing ) >> temp_to_keep

    cat $( grep to_merge listing ) temp_to_keep > "$outdir/merged-by-field/${gfs_prefix}.ALL.0p25.grb2"

    if [[ "$have_hafs" == YES ]] ; then
        for hafs in "$outdir"/*parent.atm.f000.grb2 ; do
            storm_cycle_type=$( basename "$hafs" | sed "s,.${hafs_suffix},,g" )
            outfile="$outdir/merged-by-field/${storm_cycle_type}.ALL.0p25.grb2"
            cat $( grep "$storm_cycle_type" listing ) temp_to_keep > "$outfile"
        done
    fi

    rm -f temp_to_keep

    cd ..
}

wgrib2_to_netcdf() {
    rm -rf "$outdir/as-netcdf"
    mkdir "$outdir/as-netcdf"

    rm -f cmdfile

    for grb2 in "$outdir/merged-by-field"/*grb2 ; do
        nc="$outdir/as-netcdf"/$( basename "$grb2" | sed 's,grb2$,nc,g' )
        echo wgrib2 "$grb2" -nc4 -netcdf "$nc"
    done > cmdfile

    export SCR_CMDFILE=cmdfile
    export SCR_IMMEDIATE_EXIT=no
    export SCR_PGMMODEL=MPMD
    srun -l "$mpiserial"
}

generate_itag() {
    cat > itag <<EOF
&model_inputs
! From ${s3_gfs_atm}
filename='${gfs_atm}'
IOFORM='netcdf'
grib='grib2'
DateStr='${YYYY}-${MM}-${DD}_${HH}:00:00'
MODELNAME='GFS'
! From ${s3_gfs_sfc}
fileNameFlux='${gfs_sfc}'
/
&NAMPGB
KPO=57
rdaod=.true.

! HAFS post output pressure levels
PO=1000.,975.,950.,925.,900.,875.,850.,825.,800.,775.,750.,725.,700.,675.,650.,625.,600.,575.,550.,525.,500.,475.,450.,425.,400.,375.,350.,325.,300.,275.,250.,225.,200.,175.,150.,125.,100.,70.,50.,40.,30.,20.,15.,10.,7.,5.,3.,2.,1.,0.7,0.4,0.2,0.1,0.07,0.04,0.02,0.01,/
EOF
}

copy_upp_static_files() {
    cp "${upp_clone}/fix/nam_micro_lookup.dat" ./eta_micro_lookup.dat
    cp "${upp_clone}/parm/params_grib2_tbl_new" ./params_grib2_tbl_new
    cp "$post_control_file" ./postxconfig-NT.txt
}

run_upp() {
    time srun -l "$upp_executable" < itag
}
