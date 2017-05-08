#!/bin/bash -e

script_name=$(basename $0)

usage(){
  echo "Usage: $script_name --source source-efs-id --dest dest-efs-id --subnet-id subnet-id [--instance-type t2.xlarge]" >&2
  exit 1
}

parse_args(){
  while [[ $# -gt 0 ]]
  do
    key="$1"
    case $key in
      --source)
        source_efs=$2
        shift
        ;;
      --dest)
        destination_efs=$2
        shift
        ;;
      --subnet-id)
        subnet_id=$2
        shift
        ;;
      --instance-type)
        instance_type=$2
        shift
        ;;
      *)
        usage
        ;;
    esac
    shift
  done
}


[ $# -ge 6 ] || usage
[ $(( $# % 2  )) -eq 0 ] || usage
parse_args "$@"
aws_account_id=$(aws sts get-caller-identity --query "Account" --output text)

cfn_stack_name="efs-backup"
instance_type=${instance_type:-"t2.micro"}

vpc_id=$(aws ec2 describe-subnets --subnet-ids $subnet_id --output text --query "Subnets[0].VpcId")

source_mount_target_id=$(aws efs describe-mount-targets --file-system-id $source_efs --output text --query "MountTargets[?SubnetId==\`$subnet_id\`].MountTargetId")
dest_mount_target_id=$(aws efs describe-mount-targets --file-system-id $destination_efs --output text --query "MountTargets[?SubnetId==\`$subnet_id\`].MountTargetId")

source_efs_sg=$(aws efs describe-mount-target-security-groups --mount-target-id $source_mount_target_id --query "SecurityGroups" --output text)
dest_efs_sg=$(aws efs describe-mount-target-security-groups --mount-target-id $dest_mount_target_id --query "SecurityGroups" --output text)

aws cloudformation deploy \
  --template-file cfn/backup.yml \
  --stack-name $cfn_stack_name \
  --parameter-overrides \
  InstanceType="$instance_type" \
  SourceEFS="$source_efs" \
  DestinationEFS="$destination_efs" \
  SubnetId="$subnet_id" \
  VpcId="$vpc_id" \
  SourceMountSG="$source_efs_sg" \
  DestinationMountSG="$source_efs_sg" \
  --capabilities CAPABILITY_IAM
exit 0
