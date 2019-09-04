#!/bin/bash
# Run this script as sudo? Passworldless sudo not an option
# MAKE SURE TO ENABLE AUTOLOGIN IN RASPI-CONFIG

# Check to see if this script has been ran before and prompt to create client if so
test=$( tail -n 1 EasyAsPiInstaller.sh )
if [[ "$test" == "SERVERCOMPLETE" ]]; then
	. "$DIR/create_new_client.sh"
	exit 0
fi

#if [[ num_files_in_dir -eq 7 ]]; then
#	# Setup handling of source files
#	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
#	echo "$DIR" >> $DIR/reboot_helper.txt
#elif [[ -f $HOME/reboot_helper.txt ]]; then
#	# Not the first run, grab previously stored $DIR and cd into it
#	read -r DIR<reboot_helper.txt

# Create text-formatting variables
t_reset="\e[0;39;49m"
t_bold="\e[1m"
t_important="\e[1;31;107m"
t_readin="\e[1;93m"
prompt="Press Y for yes or N for no: "
error_msg="You must enter Y for yes or N for no. Exiting."
	
	
find_arch_and_install(){
	# Check architecture and run WireGuard installer
	pi_arch=$(dpkg --print-architecture)
	if [[ ! -f $DIR/wg_install_checkpoint2.txt ]]; then
		if [[ "$pi_arch" == "armhf" ]]; then
			echo "Alright, looks like you have a device that runs on the ARMv7 or below architecture,"
			echo "Let's install everything necessary for WireGuard, when you're ready to move on just press enter."
			read -rp "$(echo -e $t_readin"Press enter to begin WireGuard installation."$t_reset)" -e -i "" mv_fwd
			pi_type=1
			# Call setup_for_armhf script
			. "$DIR/setup_for_armhf.sh"
		else
			echo "Alright, looks like you have a device that runs on the ARMv8+ architecture,"
			echo "Let's install everything necessary for WireGuard, when you're ready to move on just press enter."
			read -rp "$(echo -e $t_readin"Press enter to begin WireGuard installation."$t_reset)" -e -i "" mv_fwd
			pi_type=0
			# Call setup for v1.2 and above script
			. "$DIR/setup_for_standard.sh"
		fi
	fi
}	
	
before_first_reboot(){
	# Display welcome ascii graphic and text
	cat $DIR/welcome_text.txt
	sleep 5

	# Make sure user has autologin set through raspi-config
	echo "
	------------------------------------------------------------------------------------------------------------
	
	
	"
	echo -e $t_important"IMPORTANT: Your device will need to reboot during the course of this installation."$t_reset
	echo ""
	echo -e "$t_bold"Please"$t_reset make sure that you have 'autologin' set using the command 'sudo raspi-config'
and navigating to 'boot options' -> 'Desktop / CLI' -> 'B2 Console Autologin'. 
This is very important for the script to function properly (since we'll be installing new kernel headers)!
Enabling this setting will allow the script to continue where it left off after rebooting.
You can immediately change it back after everything is done!"
	echo ""
	# Also check for SSH, as auto-start won't be possible
	echo -e "$t_bold"NOTE:"$t_reset if you are using SSH, you will need to manually restart the script after rebooting,
since you won't have access to the same terminal afterwards. After rebooting, type 'cd EasyAsPiInstaller' and
'./EasyAsPiInstaller.sh' and you should pick up where you left off."
	echo ""
	echo "So, are you using SSH?"
	read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" ssh_check
	if [[ "${ssh_check^^}" == "Y" ]]; then
		# Do nothing
		echo "Alright, just remember the two commands to type in after rebooting! I'll let you know once the script is done."
	elif [[ "${ssh_check^^}" == "N" ]]; then
		# We will need to reboot several times, this lets us restart the script after autologin
		# The entries are removed once the script finishes
		sudo sh -c "echo 'cd $DIR' >> /etc/profile"
		sudo sh -c "echo '. $DIR/EasyAsPiInstaller.sh' >> /etc/profile"
	fi
	echo ""
	echo "Would you like to exit to set autologin through raspi-config?"
	read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" auto_login_check
	if [[ "${auto_login_check^^}" == "Y" ]]; then	
		exit 0;
	elif [[ "${auto_login_check^^}" == "N" ]]; then
		printf "Okay, I must warn you though, this script won't function correctly without this feature.\nYou are welcome to modify it yourself, though!\n\n" 
	else
		echo "$error_msg"
	fi

	# Check if user is root
	is_root() {
		if [[ $EUID -ne 0 ]]; then
			# Not root! Return 1
			return 1
		fi
		# Root!
		return 0
	}

	if ( is_root ); then
		echo "I noticed that you're running this script as root."
	else
		echo "I noticed that you're running this script as a normal user."
	fi
	sleep 1
	echo -e $t_important"IMPORTANT: This script uses the 'sudo' command to run some commands as SuperUser."$t_reset
	echo -e "If you have a password set for sudo, you will need to enter it for each step that requires it.
You can either: A. Re-run this script with 'sudo', B. Temporarily disable/remove your password,
or C. I can run the command 'sudo --validate' which will extend the sudo timeout for 15 minutes."
	sleep 2
	echo "------------------------------------------------------------------------------------------------------------
Would you like to exit this script and do either A or B yourself? If not, I'll run 'sudo --validate' for you"
	read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "N" su_choice
	if [[ "${su_choice^^}" == "Y" ]]; then
		echo "Okay, please either: Re-run this script as sudo OR temporarily remove/disable your password and re-run"
		exit
	elif [[ "${su_choice^^}" == "N" ]]; then
		echo "Sounds good, would you like me to run sudo --validate?"
		echo "If you choose 'no', you'll need to enter your password every time sudo is called."
		read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" val_choice
		if [[ "${val_choice^^}" == "Y" ]]; then
			echo "Running sudo --validate now, you'll be required to enter your password once."
			sleep 2
			sudo --validate
		elif [[ "${val_choice^^}" == "N" ]]; then
			echo "Okay, just remember to enter your password when prompted!"
		else
			echo "$error_msg"
			exit 1
		fi
	else
		echo "$error_msg"
		exit 1
	fi
	
	find_arch_and_install
	
} # END before_first_reboot

after_first_reboot(){
	# Check that wireguard is installed
	sudo lsmod | grep wireguard
	if [ $? -eq 0 ]; then
		echo "Looking good!"
	else
		echo "Something went wrong, wireguard isn't loading after rebooting."
		echo "Before troubleshooting online, try editing the file /etc/mkinicpio.conf and searching "
		echo "for the line that reads 'MODULES=(...)'. Make sure it is uncommented and add 'wireguard'" 
		echo "to the list (no quotes), which is seperated by spaces if there are already entries. "
		echo "Thanks to Juhzuri from Reddit for the tip!"
		exit 1
	fi

	# Pre-WireGuard firewall configuration
	[[ ! -f $DIR/firewall_checkpoint_p1.txt ]] && . "$DIR/configure_firewall.sh" phase1

	. "$DIR/configure_wireguard.sh"

} # END after_first_reboot

after_wireguard_configuration(){
	# Post-WireGuard firewall configuration
	if [[ -f $DIR/firewall_checkpoint_p1.txt && ! -f $DIR/firewall_checkpoint_p2 ]]; then
		. "$DIR/configure_firewall.sh" phase2
	fi

	# Grab values from reboot helper
	wg_intrfc="$(awk '/wg_intrfc/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[0]="$(awk '/int_addr[0]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[1]="$(awk '/int_addr[1]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[2]="$(awk '/int_addr[2]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[3]="$(awk '/int_addr[3]/{print $NF}' $HOME/reboot_helper.txt)"

	if [[ -f $DIR/pihole_checkpoint.txt && -f $DIR/unbound_checkpoint.txt ]]; then
		# Done, with pihole and unbound installed
		echo "Done! Now I'll start Unbound and use the 'dig pi-hole.net @127.0.0.1 -p 5353'"
		echo "command to check if it's working. I'll run this three times with different options. "
		echo "For the first, the 'status' parameter should be equal to 'NOERROR'. This verifies that DNS is working."
		echo "I'll wait for your input at the end so you can have time to review the results."
		sleep 3
		sudo service unbound start
		# need timeout?
		dig pi-hole.net @127.0.0.1 -p 5353
		sleep 2
		echo "Now, this next test should show 'SERVFAIL' for the 'status' parameter."
		echo "This verifies that DNSSEC is established, as we are running the dig command"
		echo "against 'sigfail.verteiltesysteme.net' which replicates a website that has a failed signature."
		echo "Note: This method of DNSSEC test validation is provided by: https://dnssec.vs.uni-due.de"
		sleep 3
		dig sigfail.verteiltesysteme.net @127.0.0.1 -p 5353
		sleep 2
		echo "Finally, just to make sure that everything's working, we'll run dig against "
		echo "the domain 'sigok.verteiltesysteme.net', which as you can guess should return"
		echo "the status value of 'NOERROR'"
		sleep 3
		dig sigok.verteiltesysteme.net @127.0.0.1 -p 5353
		sleep 2
		read -rp "Press enter whenever you are ready to move forward: " -e -i "" move_forward_choice
		sleep 1
		echo "Okay, there's one last thing you need to do before Unbound is good-to-go, and unfortunately,"
		echo "you're on your own with this one! You'll need to open up a web browser on your phone or another device"
		echo "and visit your Pi-hole admin dashboard that you created in the Pi-hole installation process."
		echo "From what I can tell, it should be http://"${int_addr[0]}"/admin for IPv4,"
		echo "or http://"${int_addr[2]}"/admin for IPv6, but if you changed it to something else then use that!"
		echo "Once logged in, click the 'Settings' button on the left and then navigate to the 'DNS' tab on that page."
		echo "You'll see two sections labeled 'Upstream DNS Servers', don't touch any of them other than the field that "
		echo "is labeled 'Custom 1' for IPv4 users or both 'Custom 1' and 'Custom 3' for IPv6 users. In 'Custom 1', "
		echo "Enter '127.0.0.1#5353' and if you're using IPv6 then also enter '::1#5353' into 'Custom 3'."
		echo "Finally, underneath the box that you just edited there is a section labeled 'Interface Listening Behavior.'"
		echo "Set this to only listen to the wireguard interface, in your case: $wg_intrfc"
	elif [[ ! -f $DIR/pihole_checkpoint.txt && ! -f $DIR/unbound_checkpoint.txt ]]; then
		# Done, with no pihole or unbound
		echo "Alright, that's it! If you want to install Pi-hole or Unbound later, just check the GitHub readme for a bunch"
		echo "of guides and tips. Thank you and hope your installation went well!"
	elif [[ -f $DIR/pihole_checkpoint.txt && ! -f $DIR/unbound_checkpoint.txt ]]; then
		echo "Alright, that's it! If you want to install Unbound later, just check the GitHub readme for a bunch"
		echo "of guides and tips. You can also check the reboot_helper.txt file if you want to look over the values you've inputted."
		echo "Thank you and I hope your installation went well!" 
	else	
		echo "We're supposed to be finished, but it seems like something went wrong :("
		# Done - not sure what happened here?
	fi


	# Remove reboot files
	cd $DIR
	rm wg_install_checkpoint1.txt wg_install_checkpoint2.txt wg_config_checkpoint.txt pihole_checkpoint.txt unbound_checkpoint.txt firewall_checkpoint_p1.txt firewall_checkpoint_p2.txt
	sudo sh -c "sed -i '/EasyAsPiInstaller.sh/d' /etc/profile"
	sudo sh -c "sed -i '/EasyAsPiInstaller/d' /etc/profile"

	# Add finish "checkpoint" to allow creating clients after the server is finished
	echo "#SERVERCOMPLETE" >> $DIR/EasyAsPiInstaller.sh
} # End after_wireguard_configuration


# Execute functions 

# Check if this is the first time being run
if [[ ! -f $HOME/reboot_helper.txt ]]; then
	# If its before first reboot, set DIR and place it in reboot_helper.txt
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
	echo "$DIR" >> $HOME/reboot_helper.txt
	before_first_reboot
elif [[ -f $HOME/reboot_helper.txt ]]; then
	# Not the first run, grab previously stored DIR and cd into it
	read -r DIR < $HOME/reboot_helper.txt
	cd $DIR
	# Find what checkpoint we are at
	if [[ -f $DIR/wg_install_checkpoint1.txt && ! -f $DIR/wg_install_checkpoint2.txt ]]; then
		find_arch_and_install
	elif [[ ! -f $DIR/firewall_checkpoint_p2.txt && -f $DIR/wg_install_checkpoint.txt ]]; then
		after_first_reboot
	elif [[ -f $DIR/wg_config_checkpoint.txt && "$test" != "SERVERCOMPLETE" ]]; then
		after_wireguard_configuration
	fi
else
	echo "Something went wrong and I'm not sure where to start. Exiting."			
fi
