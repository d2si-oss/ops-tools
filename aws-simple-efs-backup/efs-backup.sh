#!/usr/bin/env bash
#
# Author: Guy-Rodrigue Koffi <guy-rodrigue.koffi@d2-si.eu>

set -e

usage(){
    echo "usage: ${0##*/} -s source-efs -d dest-efs -S subnet_id [-i instance_type]"
    return 1
}

verify_args(){
    if [ -z ${2+x} ]; then
        echo "$1 is mandatory"
        return 1
    fi
}

get_mount_target_id(){
    local efs_id=$1
    local subnet_id=$2

    aws efs describe-mount-targets \
        --file-system-id ${efs_id} \
        --output text \
        --query "MountTargets[?SubnetId==\`${subnet_id}\`].MountTargetId"
}

get_mount_target_sg(){
    local mount_target_id=$1

    aws efs describe-mount-target-security-groups \
        --mount-target-id ${mount_target_id} \
        --query "SecurityGroups" \
        --output text
}

get_stack_status(){
    local stack_name=$1
    aws cloudformation describe-stacks \
        --stack-name ${stack_name} \
        --query 'Stacks[0].StackStatus' \
        --output text
}

command -v aws >/dev/null 2>&1 ||
    { echo >&2 "awscli is missing. Aborting ..."; exit 1; }

while getopts "s:d:S:i:" arg; do
    case ${arg} in
        s) source_efs=${OPTARG} ;;
        d) destination_efs=${OPTARG} ;;
        S) subnet_id=${OPTARG} ;;
        i) instance_type=${OPTARG} ;;
        *) usage ;;
    esac
done

instance_type=${instance_type:-"t2.micro"}
vpc_id=$(aws ec2 describe-subnets \
    --subnet-ids ${subnet_id} \
    --output text \
    --query "Subnets[0].VpcId")

source_mount_target_id=$(get_mount_target_id ${source_efs} ${subnet_id})
dest_mount_target_id=$(get_mount_target_id ${destination_efs} ${subnet_id})

source_efs_sg=$(get_mount_target_sg ${source_mount_target_id})
dest_efs_sg=$(get_mount_target_sg ${dest_mount_target_id})

curr_date=$(date +%Y%m%d-%H%M)
aws cloudformation deploy \
    --stack-name "aws-simple-efs-backup-${curr_date}" \
    --template-file cfn/backup.yml \
    --parameter-overrides \
    InstanceType=${instance_type} \
    SourceEFS=${source_efs} \
    DestinationEFS=${destination_efs} \
    SubnetId=${subnet_id} \
    VpcId=${vpc_id} \
    SourceMountSG=${source_efs_sg} \
    DestinationMountSG=${source_efs_sg} \
    --capabilities CAPABILITY_IAM

echo "Backing up in progress, please check cloudformation logs"
