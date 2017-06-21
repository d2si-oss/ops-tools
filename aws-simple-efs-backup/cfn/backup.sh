#!/usr/bin/env bash
#
# Author: Guy-Rodrigue Koffi <guy-rodrigue.koffi@d2-si.eu>

set -e

stack_name=$1
src_efs=$2
dst_efs=$3
region=$4

verify_args(){
    if [ -z ${2+x} ]; then
        echo "ERR: $1 is missing, aborting backup"
        return 1
    fi
}

mount_efs(){
    efsid=$1
    mountpoint=$2
    region=$3

    mount -t nfs4 \
        -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 \
        "${efsid}.efs.${region}.amazonaws.com:/" ${mountpoint}
}

echo "===> checking script parameters"

verify_args "stack_name" ${stack_name}
verify_args "src_efs" ${src_efs}
verify_args "dst_efs" ${dst_efs}
verify_args "region" ${region}

echo "===> running backup script"

src_mount="/backup"
dst_mount="/mnt/backup"

mkdir -p ${src_mount} ${dst_mount}

mount_efs ${src_efs} ${src_mount} ${region}
mount_efs ${dst_efs} ${dst_mount} ${region}

mkdir -p -m 700 ${dst_mount}/${src_efs}/{,efsbackup-logs}

curr_date=$(date +%Y%m%d-%H%M)
logfile="${dst_mount}/${src_efs}/efsbackup-logs/${src_efs}-${curr_date}.log"

# Backup files
rsync -ah --stats --delete --numeric-ids --log-file="${logfile}" \
    ${src_mount} ${dst_mount}/${src_efs}/${curr_date}

echo "===> removing CloudFormation stack"
aws cloudformation delete-stack --stack-name ${stack_name} --region ${region}
