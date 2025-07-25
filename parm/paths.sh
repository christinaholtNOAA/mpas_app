#! /bin/bash

# This should be sourced, not executed

aws_cli="/scratch3/BMC/wrfruc/Samuel.Trahan/mpashfip/aws/cli/v2/current/bin/aws"
upp_clone="/scratch3/BMC/wrfruc/Samuel.Trahan/mpashfip/upp-f10m"
post_control_file="/scratch3/BMC/wrfruc/Samuel.Trahan/mpashfip/upp-f10m/parm/postxconfig-NT-minimal.txt"
upp_executable="${upp_clone}/exec/upp.x"
syndat_dir="/scratch3/HFIP/hwrfv3/noscrub/input/SYNDAT-PLUS/"
s3_message="s3://noaa-nws-hafs-pds/inphfsa/message"
mpiserial="/scratch3/BMC/wrfruc/Samuel.Trahan/mpashfip/aws/mpiserial/mpiserial"
