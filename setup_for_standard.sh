#!/bin/bash

echo "Thanks to u/vaporisharc92 for the setup commands for Pi's not using armhf
I only own a Zero W at the moment so I am unable to test this part of the script
Please let me know if you notice any issues."

echo $t_important"IMPORTANT: As mentioned before, your device will reboot once this script finishes, 
please make sure that you have "autologin" set using the command "sudo raspi-config"
and navigating to 'boot options'. You can change it back after everything is done!"$t_reset
# Install everything needed for WireGuard
sudo apt-get install raspberrypi-kernel-headers libmnl-dev libelf-dev build-essential git dkms
sudo apt-get update -y && sudo apt-get upgrade -y

echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list

printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable

# ↑ These commands may change in the future, when this post gets old go to this link and check before running them (check the section for Debian): https://www.wireguard.com/install/

apt update 

# ↑ Ignore the error 

apt install dirmngr

apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 7638D0442B90D010

apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC
 
apt update

apt install wireguard