#!bin/bash

echo "############################"
echo "Running install under chroot"
echo "############################"
echo ""

# Before running this script, adjust parameters in file "parameters.sh"
echo "Checking config parameters..."
source /root/arch-plasma/bin/parameters.sh

[[ $disk =~ .*sda|.*nvme0n1|.*vda ]] || { echo "Error: disk must be sda, nvme0n1 or vda"; exit 1; }
[[ -z "$gpu" ]] && { echo "Error: variable gpu undefined"; exit 1; }
echo "Done"

echo "Configuring locale..."
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
locale-gen
echo "Locale done"

echo "Installing boot loader..."

bootctl --path=/boot install
cat << EOF > /boot/loader/loader.conf
timeout 3
console-mode max
default arch.conf
EOF

# Save <part-uuid> of the ssid into a variable
if [[ $disk == "/dev/nvme0n1" ]]; then
   root_partuuid=$(blkid -s PARTUUID -o value ${disk}p3)
else
   root_partuuid=$(blkid -s PARTUUID -o value ${disk}3)
fi

if [[ $gpu == "nvidia" ]]; then
    # If using nvidia gpu, need to add additional kernel parameters.
    # nvidia.NVreg_EnableGpuFirmware=0 disables the GSP firmware, which many report causes
    # stutters in KDE Plasma. Does not work if using open version of driver (nvidia-open),
    # because the open version depends on GSP.
    # nvidia.NVreg_PreserveVideoMemoryAllocations=1 preserves video memory during suspend.
    # If there are issues duging boot, add the 'nomodeset' option.
    boot_param="rw quiet loglevel=3 nvidia_drm.modeset=1 nvidia_drm.fbdev=1 nvidia.NVreg_EnableGpuFirmware=0"
else
    boot_param="rw quiet loglevel=3"
fi

# Configure Arch Linux boot
cat << EOF > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=PARTUUID=$root_partuuid $boot_param
EOF

# Create fall-back
cat /boot/loader/entries/arch.conf | sed 's/initramfs-linux/initramfs-linux-fallback/g' > /boot/loader/entries/arch-fallback.conf

# Make sure initrd is updated
mkinitcpio -P

echo "Bootloader done"

echo "Setting root password..."
echo "Choose a password for root account"
passwd root
echo "Root password done"

echo "Creating non-root user account"
useradd -m -G wheel,libvirt $user
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
echo "Choose a password for your user account"
passwd $user
echo "Non-root account done"

echo "Creating disk mounts for backup and media"
#mkdir -p /mnt/castor
mkdir -p /media/Music
mkdir -p /media/Pictures
mkdir -p /media/Videos
echo "Disk mounts done"

# Configure systemd-resolved
rm /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

echo "Enabling systemd services..."
systemctl enable nftables
systemctl enable cups
systemctl enable sshd
systemctl enable fstrim.timer
systemctl enable logrotate.timer
systemctl enable reflector.timer
systemctl enable systemd-boot-update
systemctl enable systemd-timesyncd
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable iwd
systemctl enable avahi-daemon
systemctl enable avahi-daemon.socket
systemctl enable bluetooth
systemctl enable smartd
systemctl enable sddm
systemctl enable libvirtd
systemctl enable power-profiles-daemon
#systemctl enable mnt-castor.automount
systemctl enable media-Music.automount
systemctl enable media-Pictures.automount
systemctl enable media-Videos.automount
sudo systemctl enable nvidia-suspend.service
# We don't want to use hibernate
sudo systemctl disable nvidia-hibernate.service
sudo systemctl enable nvidia-resume.service
echo "Enabling services done"

echo ""
echo "#############################"
echo "Finished install under chroot"
echo "#############################"

exit 0
