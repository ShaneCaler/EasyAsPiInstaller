#!/bin/bash

echo "Huge thank you to u/vaporisharc92 for the setup commands for Pi's not using armhf
I only own a Zero W at the moment so I am unable to test this part of the script
Please let me know if you notice any issues."

echo -e "$t_important"IMPORTANT:"$t_reset As mentioned before, your device will reboot once this script finishes, 
please make sure that you have 'autologin' set using the command 'sudo raspi-config'
and navigating to 'boot options'. You can change it back after everything is done!"
read -rp "$(echo -e $t_readin"Would you like to exit to change this setting? Y for yes, N for no: "$t_reset)" -e -i "N" exit_choice
if [[ "${exit_choice^^}" == "Y" ]]; then
	echo "Okay, just rerun the script and make your way back here!"
	exit
fi

echo -e "$t_bold"NOTE:"$t_reset This will take a while, especially loading the kernel headers. 
I will show a prompt for you once everything is finished and then I'll reboot."
read -rp "$(echo -e $t_readin"Good to go? Let's do this then. Press enter whenever you're ready: "$t_reset)" -e -i "" move_fwd

# Install everything needed for WireGuard
sudo apt-get install raspberrypi-kernel-headers libmnl-dev libelf-dev build-essential dkms -y
sudo apt-get update -y && sudo apt-get upgrade -y

echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list

printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable

# ↑ These commands may change in the future, when this post gets old go to this link and check before running them (check the section for Debian): https://www.wireguard.com/install/
sleep 2
echo -e "$t_bold"NOTE:"$t_reset An error may appear in the next update command but it's safe to ignore."
sleep 2
sudo apt update -y

# ↑ Ignore the error 

sudo apt install dirmngr

sudo apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 7638D0442B90D010

sudo apt-key adv --keyserver   keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC
 
sudo apt update -y

sudo apt install wireguard -y

echo "Alright, we're (hopefully) done! Once you're ready, I'll run the command 'sudo lsmod | grep wireguard' 
before and after rebooting to test if all went well. You should see some output on both along with an error/success message.
Remember, if you're running this installer from SSH, you'll need to manually restart the script after reestablishing connection."
sleep 3

# Check that wireguard is installed
sudo lsmod | grep wireguard
if [ $? -eq 0 ]; then
	echo ""
	echo "Looking good!"
else
	echo ""
	echo "Something went wrong and wireguard wasnt installed correctly, the command 'sudo lsmod | grep wireguard' "
	echo "did not return succesful. I recommend scrolling up and checking if any part of the installation produced "
	echo "error messages and try troubleshooting online or with the GitHub readme. Once you can get that command to produce"
	echo "output, then you can continue with this installer. See you soon!"
	exit 1
fi

read -rp "$(echo -e $t_readin"Alright, ready to restart? Just press enter! "$t_reset)" -e -i "" move_fwd

# Reboot and check if wireguard loaded at boot
echo "Temporary reboot script" >> $DIR/wg_install_checkpoint.txt
sudo shutdown -r now