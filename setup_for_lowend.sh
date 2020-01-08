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
	if [[ "${exit_choice^^}" == "N" ]]; then
		echo "Okay, just rerun the script and make your way back here!"
		exit
	fi
	echo ""
	echo "Okay, I'm about to install WireGuard for your device. After you press enter, I will
install several necessary packages, run an update & upgrade, clone the WireGuard repos,
compile & install the module and wg tool using the commands 'make', 'make install',
run 'sudo modprobe WireGuard' to check if everything worked and finally, I will reboot the device."
	echo -e "$t_bold"NOTE:"$t_reset This will take a while, especially loading the kernel headers and running
the 'make' commands. So go grab a coffee and I will show a prompt for you once everything is finished!"
	read -rp "$(echo -e $t_readin"Good to go? Let's do this then. Press enter whenever you're ready: "$t_reset)" -e -i "" move_fwd

	# Install the toolchain
	sudo apt-get install libmnl-dev libelf-dev raspberrypi-kernel-headers build-essential pkg-config -y
	echo "$divider_line"
	sudo apt-get update -y && sudo apt-get upgrade -y
	echo "Temporary reboot script" >> $DIR/wg_install_checkpoint1.txt
	echo "Rebooting in 5 seconds..."
	sleep 5
	sudo shutdown -r now 
}

after_reboot() {
#	echo "
#------------------------------------------------------------------------------------------------------------
#Okay, first I will fix your newly installed kernel headers so that they work with wireguard.
#	"
#sleep 3
# run make oldconfig and make prepare on newly installed kernel headers
#cd /usr/src/linux-$(uname -r)
#sudo sh -c "make oldconfig"
#sudo sh -c "make prepare"
	
	echo "$divider_line
Alright, now it's time to get the wireguard package, extract it and install the module using 'make' and 'sudo make install'
$divider_line"	
	sleep 3
	# Clone & Compile
	cd $HOME
	#git clone https://git.zx2c4.com/WireGuard
	#wget https://git.zx2c4.com/WireGuard/snapshot/WireGuard-0.0.20190702.tar.xz
	#tar -xf WireGuard-0.0.20190702.tar.xz
	#mv WireGuard-0.0.20190702 WireGuard
	git clone https://git.zx2c4.com/wireguard-linux-compat
	git clone https://git.zx2c4.com/wireguard-tools
	
	cd $HOME/wireguard-linux-compat/src	
	sleep 2
	
	#Compile and install the module
	echo "
Executing 'make -C wireguard-linux-compat/src -j$(nproc)'
$divider_line"

	make -C wireguard-linux-compat/src -j$(nproc)

	echo "
Executing 'sudo make -C wireguard-linux-compat/src install'
$divider_line"

	sudo sh -c "make -C wireguard-linux-compat/src install"

	# Compile and install the wg tool
	echo "
Executing 'make -C wireguard-tools/src -j$(nproc)'
$divider_line"

	make -C wireguard-tools/src -j$(nproc)

	echo "
Executing 'sudo make -C wireguard-tools/src install'
$divider_line"

	sudo sh -c "make -C wireguard-tools/src install"

	echo "
Done with make commands
$divider_line"

		#sudo sh -c "echo 'wireguard' >> /etc/modules-load.d/wireguard.conf"

		# With the lower-end models we need to manually setup kernel module and loading on boot
		#sudo sh -c "modinfo wireguard"
	##if [[ $? -eq 1 ]]; then
	##sudo sh -c "depmod -a"
		#sudo sh -c " modprobe wireguard"
	##fi

	echo "$divider_line"

	echo "Alright, we're (hopefully) done! Once you're ready, I'll run the command 'sudo lsmod | grep wireguard' 
before and after rebooting to test if all went well. You should see some output on both along with an error/success message.
Remember, if you're running this installer from SSH, you'll need to manually restart the script after reestablishing connection.
$divider_line
	"
	sleep 3

	#sudo sh -c "ip link add dev wg0 type wireguard"
	
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
		sleep 15 # temporary
		#exit 1
	fi

	read -rp "$(echo -e $t_readin"Alright, ready to restart? Just press enter! "$t_reset)" -e -i "" move_fwd
	echo "Temporary reboot script" >> $DIR/wg_install_checkpoint2.txt
	# Reboot and check if wireguard loaded at boot
	sudo shutdown -r now
}

if [[ ! -f $DIR/wg_install_checkpoint1.txt ]]; then
	before_reboot
else
	after_reboot
fi