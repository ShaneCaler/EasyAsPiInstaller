#!/bin/bash
# Install WireGuard for armhf devices

# Grab necessary variables from reboot_helper
if [[ -f $HOME/reboot_helper.txt ]]; then
	DIR="$(awk '/DIR/{print $NF}' $HOME/reboot_helper.txt)"
fi

# Install everything needed for WireGuard
echo ""
sleep 3
before_reboot() {
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
	echo $divider_line
	sudo apt-get update -y && sudo apt-get upgrade -y
	echo "Temporary reboot script" >> $DIR/wg_install_checkpoint1.txt
	echo "Rebooting in 5 seconds..."
	sleep 5
	sudo shutdown -r now 
}

after_reboot() {
	echo "$divider_line
Alright, now it's time to get the wireguard package, extract it and install the module using 'make' and 'sudo make install'
$divider_line"	
	sleep 3
	
	# Clone & Compile
	cd $HOME
	git clone https://git.zx2c4.com/wireguard-linux-compat
	git clone https://git.zx2c4.com/wireguard-tools
	
	cd $HOME/wireguard-linux-compat/src	
	sleep 2
	
	#Compile and install the module
	echo "
Executing 'make -C $HOME/wireguard-linux-compat/src -j$(nproc)'
$divider_line"

	make -C $HOME/wireguard-linux-compat/src -j$(nproc)

	echo "
Executing 'sudo make -C $HOME/wireguard-linux-compat/src install'
$divider_line"

	sudo sh -c "make -C $HOME/wireguard-linux-compat/src install"

	# Compile and install the wg tool
	echo "
Executing 'make -C $HOME/wireguard-tools/src -j$(nproc)'
$divider_line"

	make -C $HOME/wireguard-tools/src -j$(nproc)

	echo "
Executing 'sudo make -C $HOME/wireguard-tools/src install'
$divider_line"

	sudo sh -c "make -C $HOME/wireguard-tools/src install"

	echo $divider_line

	echo "Alright, we're (hopefully) done! Once you're ready, I'll run the command 'sudo lsmod | grep wireguard' 
before and after rebooting to test if all went well. You should see some output on both along with an error/success message.
Remember, if you're running this installer from SSH, you'll need to manually restart the script after reestablishing connection.
$divider_line"
	sleep 3
	
	# Check that wireguard is installed
	sudo lsmod | grep wireguard
	if [ $? -eq 0 ]; then
		echo ""
		echo "Looking good, the command returned succesful!"
	else
		echo ""
		echo "It seems that the command \"sudo lsmod | grep wireguard\" did not return successful."
		echo "Don't worry just yet, though, as this will likely be fixed after we reboot."
		echo "I recommend using Shift+Page-up/Page-down to scroll up and check if any part of the installation produced "
		echo "error messages and try troubleshooting online or with the GitHub readme. If there are no errors, just wait to see "
		echo "if the command returns successful after rebooting (I will run it and display the results for you)."
		echo $divider_line
		echo "Sleeping for 10 seconds before rebooting..."
		sleep 10
	fi

	echo "Temporary reboot script" >> $DIR/wg_install_checkpoint2.txt
	
	# Reboot
	sudo shutdown -r now
}

if [[ ! -f $DIR/wg_install_checkpoint1.txt ]]; then
	before_reboot
else
	after_reboot
fi