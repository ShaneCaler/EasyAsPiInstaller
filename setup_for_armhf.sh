#!/bin/bash
# Install WireGuard for armhf devices

# Install everything needed for WireGuard
sudo apt-get install raspberrypi-kernel-headers libmnl-dev libelf-dev build-essential git dkms
sudo apt-get update -y && sudo apt-get upgrade -y
#sudo reboot - not needed?

# Clone & Compile
git clone https://git.zx2c4.com/WireGuard
cd $DIR/WireGuard/src
make
sudo make install

# With the lower-end models we need to manually setup kernel module and loading on boot
sudo modprobe wireguard
echo "wireguard" >> /etc/modules-load.d/wireguard.conf

echo "Temporary reboot script" >> $DIR/wireguard_checkpoint.txt
# Reboot and check if wireguard loaded at boot
sudo shutdown -r now
# end setup_for_armhf