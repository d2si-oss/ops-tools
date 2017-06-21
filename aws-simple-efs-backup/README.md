# simple-efs-backup
Backup EFS data to another EFS


## Description
This tool launches a cloudformation template to do the following:

- Launch an EC2 instance
- Setup appropriate permissions
- Mount both EFS mount points
- Sync data from source to destination
- Terminate EC2 instance


## Requirements

- Minimum IAM permissions to launch stack:
  - Cloudformation admin
  - IAM admin
  - EFS read only
  - EC2 admin
- EFS file systems with mount points and security groups allowing incoming traffic.
- A subnet where both source and destination EFS mount points are available.


## Usage
Example :

```bash
git clone https://github.com/d2si-oss/ops-tools
cd ops-tools/aws-simple-efs-backup
./efs-backup.sh -s fs-e41bd42d -d fs-e21bd42b -S subnet-e94dff8d
```

### Files on source file system:

```bash
ll
total 1048592
-rw-r--r-- 1 root root 1073741824 May 30  2008 1GB.zip
-rw-r--r-- 1 root root       8219 May  6 20:38 cloud-init-output.log
-rw------- 1 root root        439 May  6 20:38 yum.log
```

### Backup file system after operation

```bash
tree
.
└── fs-e41bd42d
    ├── 20170508-1607
    │   ├── cloud-init-output.log
    ├── 20170508-1722
    │   ├── 1GB.zip
    │   ├── cloud-init-output.log
    │   └── yum.log
    └── efsbackup-logs
        ├── fs-e41bd42d-20170508-1607.log
        └── fs-e41bd42d-20170508-1722.log
```

## Roadmap

- Export backup logs into cloudwatch
- Parameterize backups rotation (currently fixed to 10)
