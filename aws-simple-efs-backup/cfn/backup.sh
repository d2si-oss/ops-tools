#!/bin/bash -e

stack_name=$1
source_efs=$2
destination_efs=$3
region=$4
retain=10
efsid=$source_efs

echo "Running backup script"

mkdir /backup
mkdir /mnt/backups
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 $source_efs.efs.eu-west-1.amazonaws.com:/ /backup
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 $destination_efs.efs.eu-west-1.amazonaws.com:/ /mnt/backups

# we need to calculate date - retain to know directory we have to remove
let "retain=$retain-1"
if test -d /mnt/backups/$efsid/$interval.$retain; then
  rm -rf /mnt/backups/$efsid/$interval.$retain
fi

# First create directory if doesn't exist
if [ ! -d /mnt/backups/$efsid ]; then
  mkdir -p /mnt/backups/$efsid
  chmod 700 /mnt/backups/$efsid
fi
if [ ! -d /mnt/backups/$efsid/efsbackup-logs ]; then
  mkdir -p /mnt/backups/$efsid/efsbackup-logs
  chmod 700 /mnt/backups/$efsid/efsbackup-logs
fi

rm -f /tmp/efs-backup.log
rsync -ah --stats --delete --numeric-ids --log-file=/tmp/efs-backup.log /backup/ /mnt/backups/$efsid/`date +%Y%m%d-%H%M`/
cp /tmp/efs-backup.log /mnt/backups/$efsid/efsbackup-logs/$efsid-`date +%Y%m%d-%H%M`.log

echo "removing cloudformation stack"
aws cloudformation delete-stack --stack-name $stack_name --region $region
