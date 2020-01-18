#!/bin/bash

# Grab necessary variables from reboot_helper
if [[ -f $HOME/reboot_helper.txt ]]; then
	DIR="$(awk '/DIR/{print $NF}' $HOME/reboot_helper.txt)"
fi

before_reboot(){
	echo "$divider_line"
	
	echo -e "$t_bold"NOTE:"$t_reset This will take a while, especially loading the kernel headers. 
	I will show a prompt for you once everything is finished and then I'll reboot."
	read -rp "$(echo -e $t_readin"Good to go? Let's do this then. Press enter whenever you're ready: "$t_reset)" -e -i "" move_fwd

	# Install everything needed for WireGuard
	sudo apt-get install raspberrypi-kernel-headers libmnl-dev libelf-dev build-essential dkms -y
	sudo apt-get update -y && sudo apt-get upgrade -y

	echo "Temporary reboot script" >> $DIR/wg_install_checkpoint1.txt
	sudo shutdown -r now
}

after_reboot() {
	echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list

	printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' > /etc/apt/preferences.d/limit-unstable

	# ↑ These commands may change in the future, when this post gets old go to this link and check before running them (check the section for Debian): https://www.wireguard.com/install/
	sleep 2
	echo -e "$t_bold"NOTE:"$t_reset An error may appear in the next update command but it's safe to ignore."
	sleep 2
	sudo apt update -y

	# ↑ Ignore the error 

	sudo apt install dirmngr

	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8B48AD6246925553

	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 7638D0442B90D010
	
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC
	
	sudo apt update -y

	sudo apt install wireguard -y
	
	echo $divider_line
	echo "Alright, we're (hopefully) done! Now I'll run the command \"sudo lsmod | grep wireguard\" 
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
		echo "It seems that the command \"sudo lsmod | grep wireguard\" did not return successful."
		echo "Don't worry just yet, though, as this will likely be fixed after we reboot."
		echo "I recommend using Shift+Page-up/Page-down to scroll up and check if any part of the installation produced "
		echo "error messages and try troubleshooting online or with the GitHub readme. If there are no errors, just wait to see "
		echo "if the command returns successful after rebooting (I will run it and display the results for you)."
		echo $divider_line
		echo "Sleeping for 10 seconds before rebooting..."
		sleep 10 # temporary
		#exit 1
	fi

	# Reboot and check if wireguard loaded at boot
	echo "Temporary reboot script" >> $DIR/wg_install_checkpoint2.txt
	sudo shutdown -r now
}

if [[ ! -f $DIR/wg_install_checkpoint1.txt ]]; then
	before_reboot
else
	after_reboot
fi