#!/bin/bash
# Install WireGuard for armhf devices

# Install everything needed for WireGuard
echo ""
sleep 3
before_reboot() {
	echo -e "$t_important"IMPORTANT:"$t_reset As mentioned before, your device will reboot once this script finishes, 
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
the 'make' command. So go grab a coffee and I will show a prompt for you once everything is finished!"
	read -rp "$(echo -e $t_readin"Good to go? Let's do this then. Press enter whenever you're ready: "$t_reset)" -e -i "" move_fwd

	sudo apt-get install raspberrypi-kernel-headers libmnl-dev libelf-dev build-essential dkms -y
	echo "
------------------------------------------------------------------------------------------------------------
	"
	sudo apt-get update -y && sudo apt-get upgrade -y
	echo "Temporary reboot script" >> $DIR/wg_install_checkpoint1.txt
	sudo shutdown -r now 
}

after_reboot() {
	echo "
------------------------------------------------------------------------------------------------------------
	"
	# Clone & Compile
	cd $HOME
	git clone https://git.zx2c4.com/WireGuard
	cd $HOME/WireGuard/src
	echo "
Executing 'make'
------------------------------------------------------------------------------------------------------------
	"

	sudo sh -c "make"

	echo "
Executing 'make check'
------------------------------------------------------------------------------------------------------------
	"

	sudo sh -c "make check"

	echo "
Executing 'make install'
------------------------------------------------------------------------------------------------------------
	"

	sudo sh -c "make install V=1"

	echo "
Done with make commands
------------------------------------------------------------------------------------------------------------
	"

	sudo sh -c "echo 'wireguard' >> /etc/modules-load.d/wireguard.conf"


	# With the lower-end models we need to manually setup kernel module and loading on boot
	sudo sh -c "modinfo wireguard"
	#if [[ $? -eq 1 ]]; then
	sudo sh -c "depmod -a"
	sudo sh -c " modprobe wireguard"
	#fi


	echo "
------------------------------------------------------------------------------------------------------------
	"

	echo "Alright, we're (hopefully) done! Once you're ready, I'll run the command 'sudo lsmod | grep wireguard' 
before and after rebooting to test if all went well. You should see some output on both along with an error/success message.
Remember, if you're running this installer from SSH, you'll need to manually restart the script after reestablishing connection.

------------------------------------------------------------------------------------------------------------
	"
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
	echo "Temporary reboot script" >> $DIR/wg_install_checkpoint2.txt
	# Reboot and check if wireguard loaded at boot
	sudo shutdown -r now
}

if [[ ! -f $DIR/wg_install_checkpoint1 ]]; then
	before_reboot
else
	after_reboot
fi