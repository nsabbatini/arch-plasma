#!/bin/bash

echo "######################"
echo "Running install script"
echo "######################"
echo ""

bin_dir="/root/arch-plasma/bin"

# Before running this script, define parameters in file parameters.sh
echo "Checking config parameters..."
source $bin_dir/parameters.sh

[[ $disk =~ .*sda|.*nvme0n1|.*vda ]] || { echo "Error: disk must be sda, nvme0n1 or vda"; exit 1; }
[[ -z "$host" ]] && { echo "Error: variable host undefined"; exit 1; }
[[ -z "$gpu" ]] && { echo "Error: variable gpu undefined"; exit 1; }
echo "Done"

# Select packages to be installed
if [[ $gpu == "intel" ]]; then
    pkgs="$bin_dir/pkg_list.txt $bin_dir/pkg_list_intel.txt"
elif [[ $gpu == "nvidia" ]]; then
    pkgs="$bin_dir/pkg_list.txt $bin_dir/pkg_list_nvidia.txt"
else
    echo "Error: wrong GPU type specified in parameters.sh"
    exit 1
fi

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
    mkpart swap linux-swap 1050624s 9439231s \
    mkpart root ext4 9439232s 100% \
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
echo $host > /mnt/etc/hostname
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

# NVIDIA environment variable
write_nvidia_config_files() {

# Environment variables to force Nvidia GBM (Generic Buffer Management)
# See https://linuxiac.com/nvidia-with-wayland-on-arch-setup-guide/
cat << EOF > /mnt/etc/environment
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
EOF

# Nvidia drivers configuration (not needed because Arch configures this by default
#cat << EOF > /mnt/etc/modprobe.d/nvidia.conf
#options nvidia NVreg_PreserveVideoMemoryAllocations=1 NVreg_TemporaryFilePath=/var/tmp
#EOF
}

# pacman hook to run mkinitcpio when NVIDIA drivers are updated
# This is only required when not using the dkms driver version
write_nvidia_pacman_hook() {
cat << EOF > /mnt/etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-open
Target=linux

[Action]
Description=Updating NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
EOF
}

if [[ $gpu == "nvidia" ]]; then
    echo "Optimizing initramfs and environment variables for NVIDIA"
    sed -Ei 's/^MODULES=\(\)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /mnt/etc/mkinitcpio.conf
    sed -Ei 's/^(HOOKS.*) kms (.*)$/\1 \2/g' /mnt/etc/mkinitcpio.conf
    write_nvidia_config_files
    # If using dmks driver version, the following is not needed
    #write_nvidia_pacman_hook
    echo "Done"
fi

echo "Configuring smartctl..."
echo "$disk -a -o on -S on -s (S/../.././02|L/../../6/03)" > /mnt/etc/smartd.conf
echo "Done"

echo "Copying install data to run under chroot..."
cp -r /root/arch-plasma /mnt/root/
echo "Done"

echo "Invoking install script to be run under chroot..."
arch-chroot /mnt bash -c "/root/arch-plasma/bin/arch-chroot.sh > >(tee -a /root/arch-chroot.stdout.log) 2> >(tee -a /root/arch-chroot.stderr.log >&2)"
echo "Done"

echo ""
echo "#######################"
echo "Finished install script"
echo "#######################"

exit 0
