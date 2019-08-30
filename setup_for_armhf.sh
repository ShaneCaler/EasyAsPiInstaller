#!/bin/bash
# Install WireGuard for armhf devices

# Install everything needed for WireGuard
echo "$t_important"IMPORTANT:"$t_reset As mentioned before, your device will reboot once this script finishes, 
please make sure that you have 'autologin' set using the command 'sudo raspi-config'
and navigating to 'boot options'. You can change it back after everything is done!"
read -rp "$(echo -e $t_readin"Would you like to exit to change this setting? Y for yes, N for no: "$t_reset)" -e -i "N" exit_choice
if [[ "${exit_choice^^}" == "Y" ]]; then
	echo "Okay, just rerun the script and make your way back here!"
	exit
fi
echo ""
echo "Okay, I'm about to install WireGuard for your armhf device. After you press enter, I will
first install several necessary packages, run an update & upgrade, clone the WireGuard repo,
run the commands 'make', 'make install' and 'sudo modprobe WireGuard' and finally reboot the device."
echo -e "$t_bold"NOTE:"$t_reset This will take a while, especially loading the kernel headers and running
the 'make' command. I will show a prompt for you once everything is finished and then I'll reboot."
read -rp "$(echo -e $t_readin"Good to go? Let's do this then. Press enter whenever you're ready: "$t_reset)" -e -i "" move_fwd

sudo apt-get install raspberrypi-kernel-headers libmnl-dev libelf-dev build-essential dkms -y
sudo apt-get update -y && sudo apt-get upgrade -y
#sudo reboot - not needed yet?

# Clone & Compile
cd $HOME
git clone https://git.zx2c4.com/WireGuard
cd $HOME/WireGuard/src
make
sudo make install

# With the lower-end models we need to manually setup kernel module and loading on boot
sudo modprobe wireguard
echo "wireguard" >> /etc/modules-load.d/wireguard.conf

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
echo "Temporary reboot script" >> $DIR/wg_install_checkpoint.txt
# Reboot and check if wireguard loaded at boot
sudo shutdown -r now