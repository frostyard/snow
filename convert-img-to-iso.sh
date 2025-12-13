#!/bin/bash

set -e

# This script converts a raw image with 512 byte sectors to an iso with 2048 byte sectors. The conversion
# allows for booting of the resulting iso as a (virtual) CDROM.

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <input img>"
    exit 1
fi

if [ $EUID -ne 0 ]; then
     echo "This script must be run as root"
     exit 1
fi

SRC=$1
DST="${SRC//.img/.iso}"

cp "$SRC" "$DST"
truncate --size +1MiB "$DST"
sgdisk -Z "$DST"

SRCLOOPDEV=$(losetup --find --show --partscan "$SRC")
DSTLOOPDEV=$(losetup --sector-size 2048 --find --show "$DST")

PART1GUID=$(sgdisk -i 1 "$SRC" | grep "Partition unique GUID:" | sed -e "s/Partition unique GUID: //")
PART2GUID=$(sgdisk -i 2 "$SRC" | grep "Partition unique GUID:" | sed -e "s/Partition unique GUID: //")
PART3GUID=$(sgdisk -i 3 "$SRC" | grep "Partition unique GUID:" | sed -e "s/Partition unique GUID: //")

echo "PART1GUID: $PART1GUID"
echo "PART2GUID: $PART2GUID"
echo "PART3GUID: $PART3GUID"

PART1NAME=$(sgdisk -i 1 "$SRC" | grep "Partition name:" | sed -e "s/Partition name: '//" | sed -e "s/'//")
PART2NAME=$(sgdisk -i 2 "$SRC" | grep "Partition name:" | sed -e "s/Partition name: '//" | sed -e "s/'//")
PART3NAME=$(sgdisk -i 3 "$SRC" | grep "Partition name:" | sed -e "s/Partition name: '//" | sed -e "s/'//")

echo "PART1NAME: $PART1NAME"
echo "PART2NAME: $PART2NAME"
echo "PART3NAME: $PART3NAME"

sgdisk -n 1::+100MiB -u "1:$PART1GUID" -t 1:21686148-6449-6E6F-744E-656564454649 -c 1:"$PART1NAME" "$DSTLOOPDEV"
sgdisk -n 2::+512MiB -u "2:$PART2GUID" -t 2:c12a7328-f81f-11d2-ba4b-00a0c93ec93b -c 2:"$PART2NAME" "$DSTLOOPDEV"
sgdisk -n 3:: -u "3:$PART3GUID" -t 3:4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709 -c 3:"$PART3NAME" "$DSTLOOPDEV"
# sgdisk -n ::+16KiB -u "3:$PART3GUID" -t 3:E7BB33FB-06CF-4E81-8273-E543B413E2E2 -c "3:$PART3NAME" "$DSTLOOPDEV"
#     sgdisk -n 4::+100MiB -u "4:$PART4GUID" -t 4:77FF5F63-E7B6-4633-ACF4-1565B864C0E6 -c "4:$PART4NAME" "$DSTLOOPDEV"
#     sgdisk -n 5::+1024MiB -u "5:$PART5GUID" -t 5:8484680C-9521-48C6-9C11-B0720656F69E -c "5:$PART5NAME" "$DSTLOOPDEV"


partprobe "$DSTLOOPDEV"

dd if="${SRCLOOPDEV}p1" of="${DSTLOOPDEV}p1" status=progress
dd if="${SRCLOOPDEV}p2" of="${DSTLOOPDEV}p2" status=progress
dd if="${SRCLOOPDEV}p3" of="${DSTLOOPDEV}p3" status=progress


losetup -d "$SRCLOOPDEV"
losetup -d "$DSTLOOPDEV"