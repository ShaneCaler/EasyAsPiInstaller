#!/bin/bash

# Check to see if this script has been ran before and prompt to create client if so
# TODO write create_new_client.sh
finishedTest=$( tail -n 1 EasyAsPi.sh )
if [[ "$finishedTest" == "SERVERCOMPLETE" ]]; then
	. "$DIR/create_new_client.sh"
	exit 0
fi

# If reboot_helper isn't already made, then create it and set $DIR to the EasyAsPiInstaller directory ($HOME/EasyAsPiInstaller)
if [[ ! -f $HOME/reboot_helper.txt ]]; then
	# If its before first reboot, set DIR and place it in reboot_helper.txt
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
	echo "DIR $DIR" >> $HOME/reboot_helper.txt
fi

# Grab necessary variables from reboot_helper
if [[ -f $HOME/reboot_helper.txt ]]; then
	DIR="$(awk '/DIR/{print $NF}' $HOME/reboot_helper.txt)"
	saved_firewall_choice="$(awk '/firewall_choice/{print $NF}' $HOME/reboot_helper.txt)"
	pi_type="$(awk '/pi_type/{print $NF}' $HOME/reboot_helper.txt)"
	wg_intrfc="$(awk '/wg_intrfc/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[0]="$(awk '/int_addr[0]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[1]="$(awk '/int_addr[1]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[2]="$(awk '/int_addr[2]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[3]="$(awk '/int_addr[3]/{print $NF}' $HOME/reboot_helper.txt)"
	pihole_choice="$(awk '/pihole_choice/{print $NF}' $HOME/reboot_helper.txt)"
	unbound_choice="$(awk '/unbound_choice/{print $NF}' $HOME/reboot_helper.txt)"
	ipv6_choice="$(awk '/ipv6_choice/{print $NF}' $HOME/reboot_helper.txt)"
fi

# Create text-formatting variables
t_reset="\e[0;39;49m"
t_bold="\e[1m"
t_important="\e[1;31;107m"
t_readin="\e[1;93m"
prompt="Press Y for yes or N for no: "
error_msg="You must enter Y for yes or N for no. Exiting."
divider_line="

------------------------------------------------------------------------------------------------------------

"	

if [[ ! -f $DIR/EAPHelper_checkpoint.txt ]]; then
	. "$DIR/EAPHelper.sh"
fi

# Check if user wants pi-hole/if pi-hole was installed
if [[ "${pihole_choice^^}" == "Y" && ! -f $DIR/pihole_checkpoint.txt ]]; then
	. "$DIR/configure_pihole_unbound.sh" pihole
elif [[ -f $DIR/pihole_checkpoint.txt ]]; then
	echo "Alright, let's check to see if Pi-hole works by using the \"host\" command."
	echo "First, I will run it against the server host using Pi-hole's DNS to verify that it is active,"
	echo "And then I'll run it against 'pagead2.googlesyndication.com' to verify that ads are being served"
	echo "By the Pi-hole. You should see the custom IP that you set earlier next to \"has address\""
	if [[ "${ipv6_choice^^}" == "Y" ]]; then
		echo -e $t_bold"Running '# host $HOSTNAME ${int_addr[0]}"$t_reset
		host $HOSTNAME ${int_addr[0]}
		echo -e $t_bold"Running '# host pagead2.googlesyndication.com ${int_addr[0]}"$t_reset
		host pagead2.googlesyndication.com ${int_addr[0]}
		read -rp "I'll pause until you press enter so you can review" -e -i "" check_pi_install
	else
		echo -e $t_bold"Running '# host $HOSTNAME ${int_addr[2]}"$t_reset
		host $HOSTNAME ${int_addr[2]}
		echo -e $t_bold"Running '# host pagead2.googlesyndication.com ${int_addr[2]}"$t_reset
		host pagead2.googlesyndication.com ${int_addr[2]}
		read -rp "I'll pause until you press enter so you can review" -e -i "" check_pi_install
	fi
fi

# Call the corresponding wireguard setup script for the user's device
if [[ ! -f $DIR/wg_install_checkpoint1.txt && $pi_type == 0 ]]; then
		. "$DIR/setup_for_lowend.sh"
elif [[ ! -f $DIR/wg_install_checkpoint1.txt && $pi_type == 1 ]]; then
	echo "Alright, looks like you have a device that runs on modern architecture!"
	sleep 2
	echo "$divider_line"
	echo "Let's install everything necessary for WireGuard, when you're ready to move on just press enter."
	read -rp "$(echo -e $t_readin"Press enter to begin WireGuard installation."$t_reset)" -e -i "" mv_fwd	
	pi_type=1
	# Add pi type to reboot_helper
	echo "pi_type $pi_type" >> $HOME/reboot_helper.txt
	
	# Call setup for v1.2 and above script
	. "$DIR/setup_for_standard.sh"
else
	echo $error_msg
	exit 1
fi

if [[ -f $DIR/wg_install_checkpoint1.txt && ! -f $DIR/wg_install_checkpoint2.txt ]]; then
	# If we are at checkpoint 1 for wireguard installation, run setup script again
	# TODO remove read to make this automatic		
	echo "Alright, we're back from the first reboot. Ready to continue?"
	read -rp "$(echo -e $t_readin"Press enter to begin WireGuard installation."$t_reset)" -e -i "" mv_fwd
	if [[ $pi_type == 0 ]]; then	
		. "$DIR/setup_for_lowend.sh"
	else
		. "$DIR/setup_for_standard.sh"
	fi
fi

# Check that wireguard is installed
echo $divider_line
read -rp "$(echo -e $t_readin"Okay, we've rebooted. Press enter to check if wireguard is still loaded: "$t_reset)" -e -i "" mv_fwd
sudo lsmod | grep wireguard
echo $divider_line
if [ $? -eq 0 ]; then
	echo "Looking good, the command to check for wireguard returned successful!"
else
	echo "Something went wrong, wireguard isn't loading after rebooting."
	echo "Before troubleshooting online, try editing the file /etc/mkinicpio.conf and searching "
	echo "for the line that reads 'MODULES=(...)'. Make sure it is uncommented and add 'wireguard'" 
	echo "to the list (no quotes), which is seperated by spaces if there are already entries. "
	echo "Thanks to Juhzuri from Reddit for the tip!"
	exit 1
fi

# Call phase1 of the configure_firewall script
if [[ ! -f $DIR/firewall_checkpoint_p1.txt ]]; then
	. "$DIR/configure_firewall.sh" phase1
fi
	
# Move on to Wireguard configuration
echo "$divider_line"
echo "Alright, now lets begin configuring Wireguard!"
echo $divider_line
sleep 2
if [[ ! -f $DIR/wg_config_checkpoint.txt ]]; then
	. "$DIR/configure_wireguard.sh"
fi

# Post-WireGuard firewall configuration
if [[ "${saved_firewall_choice^^}" == "Y" && ! -f $DIR/firewall_checkpoint_p2.txt ]]; then
	echo $divider_line
	echo "We will now begin phase 2 of firewall configuration!"
	echo $divider_line
	. "$DIR/configure_firewall.sh" phase2
fi

# Check if user wants unbound
if [[ "${unbound_choice^^}" == "Y" && ! -f $DIR/unbound_checkpoint.txt ]]; then
	. "$DIR/configure_pihole_unbound.sh" unbound
fi

if [[ -f $DIR/pihole_checkpoint.txt && -f $DIR/unbound_checkpoint.txt ]]; then
	# Done, with pihole and unbound installed
	echo "Done! Now I'll start Unbound and use the 'dig pi-hole.net @127.0.0.1 -p 5353'"
	echo "command to check if it's working. I'll run this three times with different options. "
	echo "For the first, the 'status' parameter should be equal to 'NOERROR'. This verifies that DNS is working."
	echo "I'll wait for your input at the end so you can have time to review the results.
	"
	sleep 3
	sudo service unbound start
	# need timeout?
	dig pi-hole.net @127.0.0.1 -p 5353
	sleep 2
	echo "
	Now, this next test should show 'SERVFAIL' for the 'status' parameter."
	echo "This verifies that DNSSEC is established, as we are running the dig command"
	echo "against 'sigfail.verteiltesysteme.net' which replicates a website that has a failed signature."
	echo "Note: This method of DNSSEC test validation is provided by: https://dnssec.vs.uni-due.de
	"
	sleep 3
	dig sigfail.verteiltesysteme.net @127.0.0.1 -p 5353
	sleep 2
	echo "
	Finally, just to make sure that everything's working, we'll run dig against "
	echo "the domain 'sigok.verteiltesysteme.net', which as you can guess should return"
	echo "the status value of 'NOERROR'
	"
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
rm $HOME/reboot_helper.txt EAPHelper_checkpoint.txt wg_install_checkpoint1.txt wg_install_checkpoint2.txt wg_config_checkpoint.txt pihole_checkpoint.txt unbound_checkpoint.txt firewall_checkpoint_p1.txt firewall_checkpoint_p2.txt
sudo sh -c "sed -i '/EasyAsPi.sh/d' /etc/profile"
sudo sh -c "sed -i '/EasyAsPiInstaller/d' /etc/profile"

# Add finish "checkpoint" to allow creating clients after the server is finished
echo "#SERVERCOMPLETE" >> $DIR/EasyAsPi.sh