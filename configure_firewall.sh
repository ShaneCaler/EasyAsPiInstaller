#!/bin/bash
# $1 = phase, $2 = listen_port, $3 = modded_ip
# $4 = ipv6_choice 
# $5 = wireguard subnet(int_addr[1] or int_addr[4])
# Check what phase we are in:
if [[ $1 == "phase1" ]]; then
	# Pre-configuration of firewall settings
	
	# Ask to use iptables or nftables
	echo "Would you like to upgrade your firewall from iptables (legacy) to the newer nftables?
	$t_important"DISCLAIMER: Upgrade at your own risk!!"$t_reset I $t_bold"-highly-"$t_reset recommend reviewing this script's code
	and adjusting as needed. I'm still learning firewall rules, so the following settings have
	been gathered from various resources (which I will list in the Github readme file)."
	read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "N" table_choice
	if [[ "${table_choice^^}" == "Y" ]]; then
		sudo aptitude install nftables -y
		sudo update-alternatives --set iptables /usr/sbin/iptables-legacy
		sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
		sudo update-alternatives --set arptables /usr/sbin/arptables-legacy
		sudo update-alternatives --set ebtables /usr/sbin/ebtables-legacy
		sudo systemctl enable nftables.service
		
		# Disable iptables
		sudo iptables -F
		sudo ip6tables -F
	elif [[ "${table_choice^^}" == "N" ]]; then
		echo "Okay, moving on then..."
	else
			echo "You must type Y or N to continue, please start over"
			exit 1
	fi

	# Enable IPv4 and IPv6 forwarding and avoid rebooting
	echo "
	----------------------------------------------------------------------------------------------------------------------------
	Would you like to use IPv6? If you don't know what that is or how it works, then
	A. Look it up! and B. just enter 'N' for now.
	"
	read -rp "$(echo -e $t_readin"Enter Y for yes, N for no (Only choose 'Y' if you know what you are doing!): "$t_reset)" -e -i "N" ipv6_choice
	sudo perl -pi -e 's/#{1,}?net.ipv4.ip_forward ?= ?(0|1)/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
	if [[ "{$ipv6_choice^^}" == "Y" ]]; then
			sudo perl -pi -e 's/#{1,}?net.ipv6.conf.all.forwarding ?= ?(0|1)/net.ipv6.conf.all.forwarding = 1/g' /etc/sysctl.conf
	elif [[ "{$ipv6_choice^^}" == "N" ]]; then
		echo "Okay, moving on then..."
	else
			echo "You must type Y or N to continue, please start over"
			exit 1
	fi
	# Done, create firewall checkpoint for phase 1
	echo "" > $DIR/firewall_checkpoint_p1.txt
else
	# Post-configuration of firewall settings	
	echo "If you changed the default port that Pi-hole uses (53), then "
	read -rp "Please enter it here (or just press enter): " -e -i "53" dns_port
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
		sudo iptables -A INPUT -s $modded_ip.0/${int_addr[1]} -p tcp -m tcp --dport $dns_port -m conntrack --ctstate NEW -j ACCEPT
		sudo iptables -A INPUT -s $modded_ip.0/${int_addr[1]} -p udp -m udp --dport $dns_port -m conntrack --ctstate NEW -j ACCEPT
		
		# Credit to HarryPynce@https://github.com/harrypnyce/ for the following rules
		# Misc.
		sudo iptables -A INPUT -i $pi_intrfc -p tcp --dport 80 -j ACCEPT
		sudo iptables -A INPUT -i $pi_intrfc -p tcp --dport 53 -j ACCEPT
		sudo iptables -A INPUT -i $pi_intrfc -p udp --dport 53 -j ACCEPT
		sudo iptables -A INPUT -i $pi_intrfc -p udp --dport 67 -j ACCEPT
		sudo iptables -A INPUT -i $pi_intrfc -p udp --dport 68 -j ACCEPT
		
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
	
	
	
	
	# Check if user wants to convert to nftables
	if [[ "{table_choice^^}" == "Y" ]]; then
		echo "I will now convert your iptables ruleset to nftables "
		echo "and list the final ruleset for a moment, please wait..."
		sudo iptables-save > savev4.txt
		sudo iptables-restore-translate -f savev4.txt > ruleset.nft
		sudo nft -f ruleset.nft
		sudo nft list ruleset
		sleep 4
		if [[ "{$ipv6_choice^^}" == "Y" ]]; then
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

fi

# Done, create firewall checkpoint for phase 2
echo "" > $DIR/firewall_checkpoint_p2.txt