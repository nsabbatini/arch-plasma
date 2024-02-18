#!/bin/bash

echo "######################"
echo "Running install script"
echo "######################"
echo ""

bin_dir="/root/arch-plasma/bin"
param="$bin_dir/parameters.sh"
pkgs="$bin_dir/pkg_list.txt"

# Before running this script, define parameters in file parameters.sh
echo "Checking config parameters..."
source $param

[[ $disk =~ .*sda|.*nvme0n1|.*vda ]] || { echo "Error: disk must be sda, nvme0n1 or vda"; exit 1; }
[[ -z "$host" ]] && { echo "Error: variable host undefined"; exit 1; }
echo "Done"

echo "Setting locale..."
timedatectl set-ntp true
timedatectl set-timezone America/Sao_Paulo
echo "Done"

echo "Creating partitions on $disk..."
if [[ $disk == "/dev/sda" ]]; then
    partition1="/dev/sda1"
    partition2="/dev/sda2"
    partition3="/dev/sda3"
elif [[ $disk == "/dev/nvme0n1" ]]; then
    partition1="/dev/nvme0n1p1"
    partition2="/dev/nvme0n1p2"
    partition3="/dev/nvme0n1p3"
else
    partition1="/dev/vda1"
    partition2="/dev/vda2"
    partition3="/dev/vda3"
fi

parted --script $disk -- \
    mklabel gpt \
    mkpart EFI-Boot fat32 2048s 1050623s \
    mkpart Swap linux-swap 1050624s 5244927s \
    mkpart root ext4 5244928s 100% \
    set 1 esp on
echo "Partitions done"

echo "Formatting and mounting partitions..."
mkfs.vfat $partition1
mkswap $partition2
mkfs.ext4 $partition3

mount $partition3 /mnt
swapon $partition2
mkdir /mnt/boot
mount $partition1 /mnt/boot/
echo "Formatting and mounting done"

echo "Downloading packages..."
cat $pkgs | sed -E '/^#/d' | sed -E '/^\s*$/d' |  pacstrap -i /mnt -
echo "Download done"

echo "Creating /etc/fstab..."
genfstab -U -p /mnt >> /mnt/etc/fstab
echo "Done"

echo "Copying configuration files..."
rsync -v -r /root/arch-plasma/etc/ /mnt/etc/
echo "Done"

echo "Configuring hostname, language, keymap..."
echo "$host" > /mnt/etc/hostname
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=br-latin1-us" > /mnt/etc/vconsole.conf
echo "Done"

echo "Creating /etc/hosts..."
cat << EOF > /mnt/etc/hosts
127.0.0.1 localhost
::1       localhost
EOF
echo "Done"

echo "Configuring smartctl..."
echo "$disk -a -o on -S on -s (S/../.././02|L/../../6/03)" > /mnt/etc/smartd.conf
echo "Done"

echo "Copying install data to run under chroot..."
cp -r /root/arch-plasma /mnt/root/
echo "Done"

echo "Invoking install script to be run under chroot..."
arch-chroot /mnt bash -c "/root/arch-plasma/bin/arch-chroot.sh | tee /root/arch-chroot.log"
echo "Done"

echo ""
echo "#######################"
echo "Finished install script"
echo "#######################"

exit 0
