#!bin/bash
# Run this script as sudo? Passworldless sudo not an option
# MAKE SURE TO ENABLE AUTOLOGIN IN RASPI-CONFIG

# Setup handling of source files
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Display welcome ascii graphic and text
cat $DIR/welcome_text.txt
sleep 3

# Create text-formatting variables
t_reset="\e[0;39;49m"
t_bold="\e[1m"
t_important="\e[1;31;107m"
t_readin="\e[1;93m"
prompt="Press Y for yes or N for no: "
error_msg="You must enter Y for yes or N for no. Exiting."

# Make sure user has autologin set through raspi-config
echo -e $t_important"IMPORTANT: Your device will need to reboot during the course of this installation, 
$t_bold"please"$t_reset make sure that you have 'autologin' set using the command 'sudo raspi-config'
and navigating to 'boot options' -> 'Desktop / CLI' -> 'B2 Console Autologin'. 
This is very important for the script to function properly (since we'll be installing new kernel headers)!
Enabling this setting will allow the script to continue where it left off after rebooting.
You can immediately change it back after everything is done!"$t_reset
echo "Would you like to exit to set autologin through raspi-config?"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" auto_login_check
if [[ "${auto_login_check^^}" == "Y" ]]; then	
	exit 0;
elif [[ "${auto_login_check^^}" == "N" ]]; then
	printf "Okay, I must warn you though, this script won't function correctly without this feature.\nYou are welcome to modify it yourself, though!\n\n" 
else
	echo "$error_msg"
fi

# We will need to reboot several times, this lets us restart the script after autologin
# The entry is removed once the script finishes
sudo echo ".$DIR/EasyAsPiInstaller.sh" >> /etc/profile

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
echo -e $t_important"IMPORTANT: This script uses the 'sudo' command to run some commands as SuperUser.
If you have a password set for sudo, you will need to enter it for each step that requires it.
You can either: A. Re-run this script with 'sudo', B. Temporarily disable/remove your password,
or C. I can run the command 'sudo --validate' which will extend the sudo timeout for 15 minutes."$t_reset
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

# Check to see if this script has been ran before
test=$( tail -n 1 EasyAsPiInstaller.sh )
if [[ "$test" == "SERVERCOMPLETE" ]]; then
	. "$DIR/create_new_client.sh"
	exit 0
fi


# Continue with server and first client setup
# Check architecture and run WireGuard installer
pi_arch=$(dpkg --print-architecture)
if [[ ! -f $DIR/wireguard_checkpoint.txt ]]; then
	if [[ "$pi_arch" == "armhf" ]]; then
		echo "armhf found"
		pi_type=1
		# Call setup_for_armhf script
		. "$DIR/setup_for_armhf.sh"
	else
		pi_type=0
		# Call setup for v1.2 and above script
		. "$DIR/setup_for_standard.sh"
	fi
fi


# Check that wireguard is installed
sudo lsmod | grep wireguard
if [ $? -eq 0 ]; then
	echo "Looking good!"
else
	printf "Something went wrong, wireguard isn't loading after rebooting.\nBefore troubleshooting online, try editing the file /etc/mkinicpio.conf and searching for the\nline that reads "MODULES=(...)" Make sure it is uncommented and add "wireguard" to the list (no quotes),\nwhich is seperated by spaces if there are already entries. Thanks to Juhzuri from Reddit for the tip! \n"
	exit 1
fi

# Pre-WireGuard firewall configuration
[[ ! -f $DIR/firewall_checkpoint_p1.txt ]] && . "$DIR/configure_firewall.sh" phase1

. "$DIR/configure_wireguard"

# Post-WireGuard firewall configuration
[[ -f $DIR/firewall_checkpoint_p1.txt && ! -f $DIR/firewall_checkpoint_p2 ]]; then
	. "$DIR/configure_firewall.sh" phase2
fi

# Remove reboot files
cd $DIR
rm wireguard_checkpoint.txt pihole_checkpoint.txt unbound_checkpoint.txt firewall_checkpoint_p1.txt firewall_checkpoint_p2.txt

# Add finish "checkpoint" to allow creating clients after the server is finished
echo "#SERVERCOMPLETE" >> $DIR/EasyAsPiInstaller.sh
