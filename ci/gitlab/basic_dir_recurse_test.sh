#!/usr/bin/env bash
#
#
set -x

test_type=$1

echo "-------setup image-----------------------"
echo "creating 512mb btrfs img"
IMG="/img"
MNT_DIR="/btrfs_mnt"
HOST_DIR="/mnt/"
PASS_FILE="$HOST_DIR/${test_type}_pass.txt"
rm -rf $PASS_FILE

mkdir -p $MNT_DIR
truncate -s512m $IMG

mkfs.btrfs -f $IMG

echo "-------mount image-----------------------"
echo "mounting it under $MNT_DIR"
mount $IMG $MNT_DIR


echo "-------setup files-----------------------"
echo "Creating 50mb test file"
dd if=/dev/urandom of=/tmp/f1 bs=1M count=50

echo "Coping to mount point directories"
TOPDIR="$MNT_DIR/"
SUBDIR="$MNT_DIR/d1/d2/d3"
mkdir -p $SUBDIR

cp -v /tmp/f1 $TOPDIR/
cp -v /tmp/f1 $SUBDIR/

loop_dev=$(/sbin/losetup --find --show $IMG)
sync

used_space2=$(df --output=used -h -m $MNT_DIR | tail -1 | tr -d ' ')

echo "-------dduper verification-----------------------"
echo "Running simple dduper --dry-run"
dduper --device ${loop_dev} --dir $MNT_DIR --recurse --dry-run

echo "Running simple dduper in default mode"
dduper --device ${loop_dev} --dir $MNT_DIR --recurse

sync
sleep 5
used_space3=$(df --output=used -h -m $MNT_DIR | tail -1 | tr -d ' ')

echo "-------results summary-----------------------"
echo "disk usage before de-dupe: $used_space2 MB"
echo "disk usage after de-dupe: $used_space3 MB"

deduped=$(expr $used_space2 - $used_space3)

if [ $deduped -eq 50 ];then
echo "dduper verification passed"
echo "dduper verification passed" > $PASS_FILE
else
echo "dduper verification failed"
fi

umount $MNT_DIR
poweroff
