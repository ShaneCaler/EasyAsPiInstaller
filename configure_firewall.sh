#!/bin/bash
# $1 = phase

# Grab variables from reboot_helper
if [[ -f $HOME/reboot_helper.txt ]]; then
	wg_intrfc="$(awk '/wg_intrfc/{print $NF}' $HOME/reboot_helper.txt)"
	pi_intrfc="$(awk '/pi_intrfc/{print $NF}' $HOME/reboot_helper.txt)"
	listen_port="$(awk '/listen_port/{print $NF}' $HOME/reboot_helper.txt)"
	pka_choice="$(awk '/pka_choice/{print $NF}' $HOME/reboot_helper.txt)"
	table_choice="(awk '/table_choice/{print $NF}' $HOME/reboot_helper.txt)"
	ipv6_choice="(awk '/ipv6_choice/{print $NF}' $HOME/reboot_helper.txt)"
fi

# Check what phase we are in
if [[ $1 == "phase1" ]]; then
	# Pre-configuration of firewall settings
	echo "Would you like me to handle firewall settings? Choose 'No' if you'd prefer to manage them yourself."
	echo "If you do choose 'No', I can't guarantee that you will achieve the expected results or level of network security."
	read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" firewall_choice
	
	# Add firewall_choice to reboot_helper
	echo "firewall_choice $firewall_choice" >> $HOME/reboot_helper.txt 
		
	if [[ "${firewall_choice^^}" == "Y" ]]; then
		# Ask to use iptables or nftables
		echo "Would you like to upgrade your firewall from iptables (legacy) to the newer nftables?"
		echo -e "$t_important"DISCLAIMER: Upgrade at your own risk!!"$t_reset"
		echo -e "I $t_bold"-highly-"$t_reset recommend reviewing this script's code and adjusting as needed. "
		echo "I'm still learning firewall rules, so the following settings have been gathered from various resources "
		echo "(which I will list in the Github readme file)."
		read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "N" table_choice
		
		# Add table_choice to reboot_helper
		echo "table_choice $table_choice" >> $HOME/reboot_helper.txt 
		
		if [[ "${table_choice^^}" == "Y" ]]; then

		elif [[ "${table_choice^^}" == "N" ]]; then
			echo "Okay, moving on then..."
		else
			echo "$error_msg"
			exit 1
		fi
	elif [[ "${firewall_choice^^}" == "N" ]]; then
		echo "Okay, I won't change any of your firewall settings (other than enabling required IPv4/IPv6 forwarding)."
		echo "Just be sure to apply them yourself ASAP! Otherwise, your server will be insecure and vulnerable to hackers!"
	else
		echo "$error_msg"
		exit 1
	fi
	
	echo "$divider_line"
	echo "I will now run the following commands to enable IPv4 and (optionally) IPv6 forwarding."
	echo "This first command does the actual forwarding: "
	echo "	'sudo perl -pi -e 's/#{1,}?net.ipv4.ip_forward ?= ?(0|1)/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf'"
	echo "		A similar variation will be used for IPv6"
	echo "Second, in order to enable IPv4/IPv6 without the need to reboot, I will run: "
	echo "	'sudo sysctl -p' and 'sudo sh -c \"echo 1 > /proc/sys/net/ipv4/ip_forward\"'"
	echo "		Likewise, a similar variation will be used for IPv6"
	sleep 3
	echo "$divider_line"
	echo "Now, before I do anything, would you like to set up Wireguard, Pi-Hole and Unbound using IPv6?"
	echo "This is completely optional and should only be chosen by those who know what they are doing. Choose 'N' to simply use IPv4!"
	read -rp "$(echo -e $t_readin"Enter Y for yes, N for no (Again, only choose 'Y' if you know what you are doing!): "$t_reset)" -e -i "N" ipv6_choice
	
	# Add ipv6_choice to reboot_helper
	echo "ipv6_choice $ipv6_choice" >> $HOME/reboot_helper.txt 
	
	# Enable IPv4 (and IPv6) forwarding and avoid rebooting
	sudo perl -pi -e 's/#{1,}?net.ipv4.ip_forward ?= ?(0|1)/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf

	if [[ "${ipv6_choice^^}" == "Y" ]]; then
		sudo perl -pi -e 's/#{1,}?net.ipv6.conf.all.forwarding ?= ?(0|1)/net.ipv6.conf.all.forwarding = 1/g' /etc/sysctl.conf
	elif [[ "${ipv6_choice^^}" == "N" ]]; then
		echo "Okay, moving on then..."
	else
		echo "You must type Y or N to continue, please start over"
		exit 1
	fi
	
	# Enable without rebooting
	sudo sysctl -p
	sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
	if [[ "${ipv6_choice^^}" == "Y" ]]; then
		sudo sh -c "echo 1 > /proc/sys/net/ipv6/conf/all/forwarding"
	fi
	
	# Done, create firewall checkpoint for phase 1
	echo "" > $DIR/firewall_checkpoint_p1.txt
else
	# Begin phase 2 - Post-configuration of firewall settings
	echo "If you changed the default port that Pi-hole uses (53), then"
	read -rp "$(echo -e $t_readin"Please enter it here (or just press enter): "$t_reset)" -e -i "53" dns_port
	# Set up iptables rules
	
	# Check if user needs NAT configured
	if [[ "${pka_choice^^}" == "Y" ]]; then
		sudo iptables -t nat -A POSTROUTING -o $wg_intrfc -j MASQUERADE
	fi

	# Track the VPN
	sudo iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

	# Identify and allow traffic on the VPN listening port
	sudo iptables -A INPUT -p udp -m udp --dport $listen_port -m conntrack --ctstate NEW -j ACCEPT

	# Allow tcp and udp recursive DNS
	modded_ip=$(echo "${int_addr[0]}" | cut -f -3 -d'.')
	sudo iptables -A INPUT -s $modded_ip.0/${int_addr[1]} -p tcp -m tcp --dport $dns_port -m conntrack --ctstate NEW -j ACCEPT
	sudo iptables -A INPUT -s $modded_ip.0/${int_addr[1]} -p udp -m udp --dport $dns_port -m conntrack --ctstate NEW -j ACCEPT
	
	# Credit to HarryPynce@https://github.com/harrypnyce/ for the following rules:
	sudo iptables -A INPUT -i $pi_intrfc -p tcp --dport 80 -j ACCEPT
	sudo iptables -A INPUT -i $pi_intrfc -p tcp --dport 53 -j ACCEPT
	sudo iptables -A INPUT -i $pi_intrfc -p udp --dport 53 -j ACCEPT
	sudo iptables -A INPUT -i $pi_intrfc -p udp --dport 67 -j ACCEPT
	sudo iptables -A INPUT -i $pi_intrfc -p udp --dport 68 -j ACCEPT
	sudo netfilter-persistent save
	sudo netfilter-persistent reload
	
	# Allow any traffic from pi's interface to go over wireguard's interface
	sudo iptables -A FORWARD -i $pi_intrfc -o $wg_intrfc -j ACCEPT

	# Allow RELATED, ESTABLISHED WireGuard interface (wg0)(point to point tunnel) traffic 
	# to internal network
	sudo iptables -A FORWARD -i $wg_intrfc -o $pi_intrfc -m state --state RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A INPUT -i lo -j ACCEPT
	sudo iptables -A INPUT -i $pi_intrfc -p icmp -j ACCEPT
	sudo iptables -A INPUT -i $pi_intrfc -p tcp --dport 22 -j ACCEPT
	sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
	sudo iptables -P FORWARD DROP
	sudo iptables -P INPUT DROP
	sudo iptables -L
	sudo systemctl enable netfilter-persistent
	sudo netfilter-persistent reload
	
	
	
	# Check if user wants to convert to nftables
	if [[ "${table_choice^^}" == "Y" ]]; then
		echo "I will now install nftables, convert your iptables ruleset"
		echo "and finally list the final ruleset for a moment, please wait..."
		sudo apt install nftables -y
		sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
		sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
		sudo update-alternatives --set arptables /usr/sbin/arptables-legacy
		sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy
		sudo systemctl enable nftables.service
			
		# Disable iptables
		sudo iptables -F
		sudo ip6tables -F
		
		# Save and translate IPv4 rules
		sudo iptables-save > savev4.txt
		sudo iptables-restore-translate -f savev4.txt > ruleset.nft
		sudo nft -f ruleset.nft
		sudo nft list ruleset
		sleep 4
		if [[ "{$ipv6_choice^^}" == "Y" ]]; then
			# Save and translate IPv6 rules
			echo "Since you chose to use IPv6, I'll run the same process, but for those rules as well."
			echo -e "$t_bold"NOTE:"$t_reset If something goes wrong, try running the commands to convert" 
			echo "IPv4 iptables instead. They are as follows: "
			echo "# sudo iptables-save > savev4.txt "
			echo "# sudo iptables-restore-translate -f savev4.txt > ruleset.nft "
			echo "# sudo nft -f ruleset.nft "
			echo "# sudo nft list ruleset "
			sudo ip6tables-save > savev6.txt
			sudo ip6tables-restore-translate -f savev6.txt > ruleset.nft
			sudo nft -f ruleset.nft
			sudo nft list ruleset
			sleep 4
		fi
	fi
	
	# Done, create firewall checkpoint for phase 2
	echo "" > $DIR/firewall_checkpoint_p2.txt
fi
