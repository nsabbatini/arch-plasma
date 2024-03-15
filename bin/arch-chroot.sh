#!bin/bash

echo "############################"
echo "Running install under chroot"
echo "############################"
echo ""

# Before running this script, adjust parameters in file "parameters.sh"
source /root/arch-plasma/bin/parameters.sh

[[ $disk =~ .*sda|.*nvme0n1|.*vda ]] || { echo "Error: disk must be sda, nvme0n1 or vda"; exit 1; }

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

# Configure Arch Linux boot
cat << EOF > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options root=PARTUUID=$root_partuuid rw quiet loglevel=3
EOF

# Create fall-back
cat /boot/loader/entries/arch.conf | sed 's/initramfs-linux/initramfs-linux-fallback/g' > /boot/loader/entries/arch-fallback.conf
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

echo "Creating disk mounts"
mkdir -p /mnt/castor
echo "Disk mounts done"

echo "Enabling systemd services..."
systemctl enable nftables
systemctl enable cups
systemctl enable sshd
systemctl enable fstrim.timer
systemctl enable logrotate.timer
systemctl enable reflector.timer
systemctl enable systemd-boot-update
systemctl enable systemd-timesyncd
systemctl enable NetworkManager
systemctl enable wpa_supplicant
systemctl enable avahi-daemon
systemctl enable bluetooth
systemctl enable smartd
systemctl enable sddm
systemctl enable libvirtd
systemctl enable power-profiles-daemon
systemctl enable mnt-castor.automount
echo "Enabling services done"

echo ""
echo "#############################"
echo "Finished install under chroot"
echo "#############################"

exit 0
