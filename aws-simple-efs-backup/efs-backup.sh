#!/usr/bin/env bash
#
# Author: Guy-Rodrigue Koffi <guy-rodrigue.koffi@d2-si.eu>

set -e

usage(){
    echo "usage: ${0##*/} -s src_efs -d dst_efs -S subnet_id [-i instance_type]"
    return 1
}

verify_args(){
    if [ -z ${2+x} ]; then
        echo "ERR: $1 is mandatory"
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
    { echo >&2 "ERR: awscli is missing, aborting!"; exit 1; }

while getopts "s:d:S:i:" arg; do
    case ${arg} in
        s) src_efs=${OPTARG} ;;
        d) dst_efs=${OPTARG} ;;
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

src_mount_target_id=$(get_mount_target_id ${src_efs} ${subnet_id})
dst_mount_target_id=$(get_mount_target_id ${dst_efs} ${subnet_id})

src_efs_sg=$(get_mount_target_sg ${src_mount_target_id})
dst_efs_sg=$(get_mount_target_sg ${dst_mount_target_id})

curdate=$(date +%Y%m%d-%H%M)

aws cloudformation deploy \
    --stack-name "aws-simple-efs-backup-${curdate}" \
    --template-file cfn/backup.yml \
    --parameter-overrides \
    InstanceType=${instance_type} \
    SourceEFS=${src_efs} \
    DestinationEFS=${dst_efs} \
    SubnetId=${subnet_id} \
    VpcId=${vpc_id} \
    SourceMountSG=${src_efs_sg} \
    DestinationMountSG=${src_efs_sg} \
    --capabilities CAPABILITY_IAM

echo "===> backup in progress, please check CloudFormation logs"
