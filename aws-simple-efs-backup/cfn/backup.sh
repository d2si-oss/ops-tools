#!/usr/bin/env bash

set -e

stack_name=$1
source_efs=$2
destination_efs=$3
region=$4


echo "Checking script parameters"
verify_args(){
    if [ -z ${2+x} ]; then
        echo "$1 is missing, aborting backup"
        return 1
    fi
}

validate_path(){
    if [[ $1 == *"../"* ]]; then
        return 1
    fi

    if [[ $1 == "/" ]]; then
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

verify_args "stack_name" ${stack_name}
verify_args "source_efs" ${source_efs}
verify_args "destination_efs" ${destination_efs}
verify_args "region" ${region}

validate_path ${source_efs}
validate_path ${destination_efs}


echo "Running backup script"

source_mount="/backup"
dest_mount="/mnt/backup"
mkdir -p ${source_mount}
mkdir -p ${dest_mount}

mount_efs ${source_efs} ${source_mount} ${region}
mount_efs ${destination_efs} ${dest_mount} ${region}

# First create directory if doesn't exist
mkdir -p -m 700 ${dest_mount}/$source_efs/{,efsbackup-logs}

curr_date=$(date +%Y%m%d-%H%M)
logfile="${dest_mount}/${source_efs}/efsbackup-logs/${source_efs}-${curr_date}.log"

# Back up files
rsync -ah --stats --delete --numeric-ids --log-file="${logfile}" \
    ${source_mount} ${dest_mount}/${source_efs}/${curr_date}

echo "Removing cloudformation stack"
aws cloudformation delete-stack --stack-name ${stack_name} --region ${region}
