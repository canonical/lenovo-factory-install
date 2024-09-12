#!/bin/bash
#
# This script is used to inject files into the recovery partition

GRUG_CFG="cloud-configs/grub/factory-install.cfg"

TARGET_DISK=$1
if [ -z "$TARGET_DISK" ]; then
    echo "Usage: $0 <disk>"
    echo "       $0 /dev/sda"
    echo "       $0 /dev/nvme0n1"
    exit 1
fi

# get the partitions of the target disk
TARGET_PARTITIONS=$(ls ${TARGET_DISK}* | grep -v ${TARGET_DISK}$)
# check the number of partitions
num_partitions=$(echo "$TARGET_PARTITIONS" | wc -l)
if [ $num_partitions -lt 2 -o $num_partitions -gt 3 ]; then
    echo "The target disk should have 2 partitions(EFI and recovery)"
    exit 1
elif [ $num_partitions -eq 3 ]; then
    echo "The third partition should be unpartitioned, do you want to continue?"
    read -p "The data on the third partition will be lost, continue? [y/N] " answer
    if [ "$answer" != "y" ]; then
        parted $TARGET_DISK rm 3
    else
        exit 0
    fi
fi
# For sda, the partitions are sda1 and sda2
# For nvme0n1, the partitions are nvme0n1p1 and nvme0n1p2
EFI_PART=$(echo "$TARGET_PARTITIONS" | grep "1$")
RECOVERY_PART=$(echo "$TARGET_PARTITIONS" | grep "2$")
EFI_TYPE=$(lsblk -no FSTYPE $EFI_PART)
if [ "$EFI_TYPE" != "vfat" ]; then
    echo "The EFI partition should be formatted as vfat"
    exit 1
fi
EFI_SIZE=$(lsblk -nbo SIZE $EFI_PART)
if [ "$EFI_SIZE" != "1127219200" ]; then
    echo "The EFI partition should be 1127219200"
    exit 1
fi

RECOVERY_TYPE=$(lsblk -no FSTYPE $RECOVERY_PART)
if [ "$RECOVERY_TYPE" != "vfat" ]; then
    echo "The recovery partition should be formatted as vfat"
    exit 1
fi
# get the partuuid of the recovery partition
RECOVERY_PARTUUID=$(lsblk -no PARTUUID $RECOVERY_PART)
# get the mount point of the recovery partition if it is mounted
RECOVERY_MOUNTPOINT=$(lsblk -no MOUNTPOINT $RECOVERY_PART)
if [ -z "$RECOVERY_MOUNTPOINT" ]; then
    RECOVERY_MOUNTPOINT="/mnt/recovery"
    mkdir -p $RECOVERY_MOUNTPOINT
    mount -o rw $RECOVERY_PART $RECOVERY_MOUNTPOINT
fi

# copy the grub config file to the recovery partition
cp $RECOVERY_MOUNTPOINT/boot/grub/grub.cfg $RECOVERY_MOUNTPOINT/boot/grub/grub.cfg.bak
cp $GRUG_CFG $RECOVERY_MOUNTPOINT/boot/grub/grub.cfg
sed -i "s/RECOVERY_PARTUUID/$RECOVERY_PARTUUID/g" $RECOVERY_MOUNTPOINT/boot/grub/grub.cfg
echo "The grub config file has been injected into the recovery partition"
echo "Please review the grub config file in the recovery partition: $RECOVERY_MOUNTPOINT/boot/grub/grub.cfg"
cat $RECOVERY_MOUNTPOINT/boot/grub/grub.cfg
