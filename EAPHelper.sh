#!/bin/bash

# Display welcome ascii graphic and text
cat $DIR/welcome_text.txt
sleep 3

# Find debian version and check whether autologin is enabled
# Credit to raspi-config authors for deb_ver and is_autologin_enabled functions
deb_ver () {
	ver=`cat /etc/debian_version | cut -d . -f 1`
	echo $ver
}

# Check if autologin has been enabled by raspi-config
is_autologin_enabled(){
	if [ -e /etc/systemd/system/getty@tty1.service.d/autologin.conf ] ; then
		# stretch or buster - is there an autologin conf file?
		return 0
	else
		# stretch or earlier - check the getty service symlink for autologin
		if [ $(deb_ver) -le 9 ] && grep -q autologin /etc/systemd/system/getty.target.wants/getty@tty1.service ; then
			return 0
		else
			return 1
		fi
	fi
}

if ( ! is_autologin_enabled ); then
	# Make sure user has autologin set through raspi-config
	echo "$divider_line"
	echo -e $t_important"IMPORTANT: Your device will need to reboot during the course of this installation."$t_reset
	echo ""
	echo -e "$t_bold"Please"$t_reset make sure that you have 'autologin' set using the command 'sudo raspi-config'
and navigating to 'boot options' -> 'Desktop / CLI' -> 'B2 Console Autologin'. 
This is very important for the script to function properly (since we'll be installing new kernel headers)!
Enabling this setting will allow the script to continue where it left off after rebooting.
You can immediately change it back after everything is done!"	
	echo "So, would you like to exit to set autologin through raspi-config?"
	read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" auto_login_check
	if [[ "${auto_login_check^^}" == "Y" ]]; then	
		exit 0;
	elif [[ "${auto_login_check^^}" == "N" ]]; then
		echo "Okay, just remember, this script may not function correctly without this feature.
You are welcome to manually log in each time if you choose not to use it though!" 
	else
		echo "$error_msg"
	fi
fi

echo $divider_line

# Check if using SSH
if pstree -p | egrep --quiet --extended-regexp ".*sshd.*\($$\)"; then
	echo -e "$t_bold"NOTE:"$t_reset I noticed that you are using SSH - you will need to manually log in and 
restart the script after rebooting each time, since you won't have access to the same terminal afterwards. 
After rebooting, type 'cd EasyAsPiInstaller' and 'sudo ./EasyAsPi.sh' and it should pick up where you left off."
else
	# We will need to reboot several times, this lets us restart the script after autologin
	# The entries are removed once the script finishes
	sudo sh -c "echo 'cd $DIR' >> /etc/profile"
	sudo sh -c "echo 'sudo sh -c \".$DIR/EasyAsPi.sh\"' >> /etc/profile"
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

# Explain that this script needs to be ran as a normal user with sudo priviledges
if ( is_root ); then
	echo "I see that you're running this script as root, this is important as many of the commands
used to complete this installation require administrative priviledges. If you are logged into a normal user account 
and simply ran this script using \"sudo ./EasyAsPi.sh\", then you are ready to move on. 
However, if you are running this script while actively logged in as sudo (i.e. by running sudo su beforehand),
some errors or challenges may occur after restarting the device, as you will likely be re-logged into your regular user account, which has a different directory structure.
To fix this, you can try logging into your user account and running this script with sudo, or you can Ctrl+C out of the script
after each reboot, and manually re-run the script after running sudo su. This isn't recommended, though. 
Sorry for the confusion! I am currently working on a better way to handle this."
	echo $divider_line
	echo "So, if you are logged into the SuperUser account, would you like to exit and try again as a regular user?"
	read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "N" su_choice
else
	echo -e $t_important"IMPORTANT: This script uses the \"sudo\" command to run some commands that require administrative priviledges."$t_reset
	echo -e "Currently, you would need to enter your password for each step that requires it, which can get tedious, so here are some options.
You can either: A. Re-run this script with 'sudo', B. Temporarily disable/remove your password,
or C. I can run the command 'sudo --validate' which will extend the sudo timeout for 15 minutes."
	sleep 1
	echo $divider_line
	read -rp "$(echo -e $t_readin""Please enter the option that you would like to choose, either A, B, or C: " "$t_reset)" -e -i "C" su_choice
	if [[ "${su_choice^^}" == "A" || "${su_choice^^}" == "B" ]]; then
		echo "Okay, I will exit now. 
Please either: Re-run this script using sudo OR temporarily remove/disable your password and re-run."
		exit 1
	elif [[ "${su_choice^^}" == "C" ]]; then
		echo "Sounds good,I will go ahead and run 'sudo --validate' now, you'll be required to enter your password once in just a moment."
		sleep 1
		sudo --validate
	else
		echo "$error_msg"
		exit 1
	fi
fi

sleep 1	
echo $divider_line

# Check pi model and revision to determine which setup script to run later
pi_model=$(cat /sys/firmware/devicetree/base/model | awk '{print $3, $4}')
pi_revision=$(cat /sys/firmware/devicetree/base/model | sed -n -e 's/^.*Rev //p')
if [[ "$pi_model" == "Zero Rev" || "$pi_model" == "Zero W" || "$pi_model" == "Model A" || "$pi_model" == "Model B" ]]; then
	echo "Alright, from what I can tell, you are using a $pi_model Raspberry Pi device, which is going to take "
	echo "some extra steps. I've got you covered, though!"
	echo $divider_line
	# Add pi type to reboot_helper to use later
	pi_type=0			
	echo "pi_type $pi_type" >> $HOME/reboot_helper.txt
elif [[ "$pi_model" == "2 Model" && "$pi_revision" != "1.2" ]]; then
	echo "Alright, looks like you're running a Raspberry Pi Model 2 Revision 1.1, which is going to take "
	echo "some extra steps. I've got you covered, though!"
	echo $divider_line
	pi_type=0
	# Add pi type to reboot_helper to user later
	echo "pi_type $pi_type" >> $HOME/reboot_helper.txt
else
	echo "Alright, looks like you have a device that runs on modern architecture!"
	echo $divider_line
	# Add pi type to reboot_helper to use later
	pi_type=1
	echo "pi_type $pi_type" >> $HOME/reboot_helper.txt
fi


echo "First things first: Would you like to install pi-hole after we set up WireGuard?
According to the developers, \"the Pi-hole is a DNS sinkhole that protects your
devices from unwanted content, without installing any client-side software.\""
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" pihole_choice
# Add pihole_choice to reboot_helper to use later
echo "pihole_choice $pihole_choice" >> $HOME/reboot_helper.txt 
if [[ "${pihole_choice^^}" == "Y" ]]; then
	echo "Great, would you also like to setup Unbound to allow pi-hole to act as a \"recursive"
	echo "DNS server\"? For info on what that is, please refer to the readme and/or"
	echo "the official pi-hole docs at https://docs.pi-hole.net/guides/unbound/"
	read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" unbound_choice
	if [[ "${unbound_choice^^}" != "Y" && "${unbound_choice^^}" != "N" ]]; then
		echo "$error_msg"
		exit 1
	fi

	# Add unbound_choice to reboot_helper to use later
	echo "unbound_choice $unbound_choice" >> $HOME/reboot_helper.txt 
	echo "Awesome, I'll keep that in mind for later!"
else
	echo "Okay, we won't set up pi-hole (or Unbound). Feel free to do so yourself later!"
fi

echo $divider_line
sleep 2

# Ask if we should create an optional preshared key for extra security
echo "Let's begin configuring Wireguard! First I will generate your private and public keys for both
your Wireguard server (the machine you're reading this on) and your first client (a smartphone, laptop, PC, etc.). 
I'll take care of them for now, but for future reference, they will be stored in: \"/etc/wireguard/\" 
along with your server & client configuration files. You will need to use \"sudo\" to access them.

Now, before I do that, would you like to generate an optional preshared key to add another layer of security to your VPN?"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" keychoice
# Add keychoice to reboot_helper to use later
echo "keychoice $keychoice" >> $HOME/reboot_helper.txt 

echo $divider_line

# Ask for interface name
echo "What would you like to name this WireGuard interface? Typically 'wg0' if this is your first time with Wireguard.
This will also be the name of the server config file located in /etc/wireguard/"
read -rp "$(echo -e $t_readin"Press enter or change if desired: "$t_reset)" -e -i "wg0" wg_intrfc
# Add wg_intrfc to reboot_helper to use later
echo "wg_intrfc $wg_intrfc" >> $HOME/reboot_helper.txt 

echo $divider_line

# Find user's current network interface and public IP addresses and add to reboot_helper
pi_intrfc="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
pi_pub_ip6=$(ip -6 addr show dev $pi_intrfc | grep 'inet6*' | awk '{print $2}' | sed '1!d' | cut -f1 -d"/")
pi_pub_ip4=$(host -4 myip.opendns.com resolver1.opendns.com | grep "myip.opendns.com has" | awk '{print $4}')
echo "pi_intrfc $pi_intrfc" >> $HOME/reboot_helper.txt 
echo "pi_pub_ip4 $pi_pub_ip4" >> $HOME/reboot_helper.txt 
echo "pi_pub_ip6 $pi_pub_ip6" >> $HOME/reboot_helper.txt 

# Ask for internal IP address and subnet
echo "Create the internal server IPv4 or IPv6 addresses that you'd like to associate with 
WireGuard in the following format: IPv4: 10.24.42.1/24 or IPv6: 1337:abcd:24::1/64
Please refer to the github readme for some documentation on subnets and IP addresses if you 
are confused. This is not the same subnet from your router, but rather one you create yourself.

TIPS:
- Any four-digit group of zeroes for IPv6 may be shortened to just 0 or : or ::
- Private IPv4 typically starts with 10 or 192, followed by three user-chosen, 1-3 digit numbers.
	- It is typical to make the server's final digit 1 (similar to the example format above)
- Avoid starting IPv6 with 2001 as they are often already registered.
- IPv4 subnet: If you don't know what to use, try 24
Examples: 192.0.0.1/32 = handle a single IP address (192.0.0.1) OR
192.0.0.1/24 = handle all 255 IP's from 192.0.0.1-255
Other common subnet values are 16, 8, or 0.
"
sleep 2
IFS='/' read -rp "$(echo -e $t_readin"Enter internal IPv4 address in the format given: "$t_reset)" -e -i "10.24.42.1/24" -a int_addr
if [[ "${ipv6_choice^^}" == "Y" ]]; then
	IFS='/' read -rp "$(echo -e $t_readin"Enter internal IPv6 address in the format given: "$t_reset)" -e -i "1337:abcd:24::1/64" -a int_addr_temp
	int_addr+=( ${int_addr_temp[@]} )
fi

# Add int_addr fields to reboot_helper 
echo "int_addr[0] ${int_addr[0]}" >> $HOME/reboot_helper.txt 
echo "int_addr[1] ${int_addr[1]}" >> $HOME/reboot_helper.txt 
echo "int_addr[2] ${int_addr[2]}" >> $HOME/reboot_helper.txt 
echo "int_addr[3] ${int_addr[3]}" >> $HOME/reboot_helper.txt 

echo $divider_line

# Ask for listen port
echo "Enter the listen port you'd like to use, commonly a number between 49152 through 65535
You can search https://www.iana.org/assignments/service-names-port-numbers for unassigned port numbers.
You will need to forward this port in your router, search google for your router model and
'port forwarding' for instructions on how to do so. Wireguard's default is 51820, 
so if in doubt you can go with that, though I'd recommend otherwise to have stronger security.
"
read -rp "$(echo -e $t_readin"Enter your desired port here: "$t_reset)" -e -i "51820" listen_port

# Add listen_port to reboot_helper
echo "listen_port $listen_port" >> $HOME/reboot_helper.txt 

echo $divider_line

# Ask for save choice
echo "Do you want to save your server config file upon termination of WireGuard connection? (i.e. reboot or service stops)"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)"  -e -i "Y" save_choice
if [[ "${save_choice^^}" == "Y" ]]; then
	save_conf="true"
elif [[ "${save_choice^^}" == "N" ]]; then
	save_conf="false"
else
	echo "$error_msg"
	exit 1
fi

# Add save_conf to reboot_helper
echo "save_conf $save_conf" >> $HOME/reboot_helper.txt 

echo $divider_line

# Ask if user wants to use Pi's DNS as Upstream server
echo "Would you like to specify the WireGuard server's IP as the DNS resolver?
Choose yes if you plan to use Unbound to set Pi-hole as a recursive DNS resolver
Using Unbound removes the need for third-party DNS upstream provider.
See https://docs.pi-hole.net/guides/unbound/ for more information.
"
dns_addr=()
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)"  -e -i "Y" dns_choice
if [[ "${dns_choice^^}" == "Y" ]]; then
    dns_choice="true"
	echo "Good choice! If you would like to add a secondary DNS provider, just append it to the following
using a comma and no spaces to seperate the addresses. Common choices: 1.1.1.1 or 8.8.8.8
Example: ${int_addr[0]},1.1.1.1"
	read -rp "$(echo -e $t_readin"Enter your secondary (IPv4) DNS provider or just press 'Enter': "$t_reset)" -e -i "${int_addr[0]}" dns_v4
	dns_addr+=($dns_v4)
	if [[ "${ipv6_choice^^}" == "Y" ]]; then
		echo "Let's do the same for ipv6."
		read -rp "$(echo -e $t_readin"Enter your secondary DNS provider or just press 'Enter': "$t_reset)" -e -i "${int_addr[2]}" dns_v6
		dns_addr+=($dns_v6)
	fi
elif [[ "${dns_choice^^}" == "N" ]]; then
	dns_choice="false"
	echo "Please enter the DNS address(es) that you'd like to use.
If you want to use more than one, seperate with a comma and no spaces.
Example: 1.1.1.1,8.8.8.8"
	read -rp "$(echo -e $t_readin"Enter your DNS address(es) here or just press 'Enter': "$t_reset)" -e -i "1.1.1.1,8.8.8.8" dns_addr
else
    echo "$error_msg"
    exit 1
fi

# Add dns_v4 and dns_v6 to reboot_helper
echo "dns_v4 $dns_v4" >> $HOME/reboot_helper.txt 
echo "dns_v6 $dns_v6" >> $HOME/reboot_helper.txt 

echo $divider_line

# Ask for network interface
echo "I've determined that you're using \"$pi_intrfc\" as a network interface, but you may change it if needed.
Typically \"eth0\" for ethernet or \"wlan0\" for wireless (no quotes, using the number \"0\" - not the letter \"o\")
"
read -rp "$(echo -e $t_readin"Enter your interface here, or just press 'enter': "$t_reset)" -e -i "$pi_intrfc" pi_intrfc

echo $divider_line

# Ask for server's allowed IP addresses for [peer] sections
echo "Please enter the \"allowed IPv4 address and subnet\" for the first peer on the server config file (you may add more later).
NOTE: 0.0.0.0/0 (IPv4) or ::/0 (IPv6) will forward all traffic through this interface! That means if your server is in New York and you
connect to Wireguard in San Francisco, all your traffic is going to look as if it's going through your home's IP address.
If you don't use 0.0.0.0/0, then you can enter the previous IPv4 address but replace the last digit with a higher number. 
i.e. if you chose 10.24.42.1 for your server, enter something like 10.24.42.2/32. This will allow one client to connect to the server.
Finally, if you want to access your Local Area Network from anywhere, simply enter the subnet associated with your router with a subnet value of /24"
read -rp "$(echo -e $t_readin"If you're still confused, press Y and I can print some more information, otherwise type N: "$t_reset)" -e -i "Y" allowed_choice
if [[ "${allowed_choice^^}" == "Y" ]]; then
echo "Excerpt from Emanuel Duss @ https://emanuelduss.ch/2018/09/wireguard-vpn-road-warrior-setup/
This option always includes only IP addresses or networks that are available on the remote site.
It's not an IP address/network outside the tunnel (so no configuration from which public IP address
a client is allowed to connect) but only addresses/networks which are transported inside the tunnel!
In a road warrior scenario, where the client does not provide a whole network to the server,
the netmask is always /32 on IPv4 or /128 on IPv6. Packets on the VPN server with this destination
IP addresses are sent to this specified peer. This peer is also only allowed to send packages from
this source IP address to the VPN server. It’s also important to know that there are no peers
with the same AllowedIPs addresses/networks inside the same configuration file. If this would be the case,
the server would not know to which peer the server has to send packages matching multiple peers with the same network configured."
fi
echo $divider_line
sleep 2
echo "Okay, now lets move forward."
sleep 1

server_allowed_ips=()
read -rp "$(echo -e $t_readin"Enter the server's allowed ipv4 address here: "$t_reset)" -e -i "10.24.42.2/32" server_allowed_ipv4
server_allowed_ips+=($server_allowed_ipv4)
if [[ "${ipv6_choice^^}" == "Y" ]]; then
	echo "Let's do the same for ipv6."
	read -rp "$(echo -e $t_readin"Enter the server's allowed ipv6 address here: "$t_reset)" -e -i "1337:abcd:24::2/128" server_allowed_ipv6
	server_allowed_ips+=($server_allowed_ipv6)
fi

# Add server_allowed_ips to reboot_helper
echo "server_allowed_ips $server_allowed_ips" >> $HOME/reboot_helper.txt 

echo $divider_line

# Ask for clients allowed IP addresses
echo "Now we will do the same but for the client's \"allowed IPv4 address and subnet\",
which should generally either be 0.0.0.0/0 (IPv4) or ::/0 (IPv6) to enable 'full tunneling',
or use the same pattern as the previously entered address(es) but with a 0 as the last digit
of the address (i.e. 10.24.42.0/32 or 1337:abcd:24::/128)
"
client_allowed_ips=()
read -rp "$(echo -e $t_readin"Enter the client's allowed IPv4 address here: "$t_reset)" -e -i "10.24.42.0/24" client_allowed_ipv4
client_allowed_ips=(${client_allowed_ipv4})
if [[ "${ipv6_choice^^}" == "Y" ]]; then
        echo "Let's do the same for ipv6."
        read -rp "$(echo -e $t_readin"Enter the client's allowed IPv6 address here: "$t_reset)" -e -i "1337:abcd:24::/128" client_allowed_ipv6
        client_allowed_ips+=($client_allowed_ipv6)
fi

# Add client_allowed_ips to reboot_helper
echo "client_allowed_ips $client_allowed_ips" >> $HOME/reboot_helper.txt 

echo $divider_line

# Ask for endpoint
echo "Would you like to setup an endpoint for the first client config file?
Note: This must be accessible via the public internet (like a domain)
but if you want, I can grab your server's public IP using the 'Host' utility.
"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)"  -e -i "Y" e_choice
if [[ "${e_choice^^}" == "Y" ]]; then
        if [[ "${ipv6_choice^^}" == "Y" ]]; then
                echo "Since you're using IPv6, you can choose between the two for the endpoint."
                read -rp "$(echo -e $t_readin"Enter '4' for IPv4 or '6' for IPv6: "$t_reset)" -e -i "6" e_ip_choice
                if [[ "$e_ip_choice" == "6" ]]; then
                        read -rp "$(echo -e $t_readin"Press enter or change if necessary: "$t_reset)" -e -i "$pi_pub_ip6" endp_ip
                elif [[ "$e_ip_choice" == "4" ]]; then
                        read -rp "$(echo -e $t_readin"Press enter or change if necessary: "$t_reset)" -e -i "$pi_pub_ip4" endp_ip
                fi
        else
                read -rp "$(echo -e $t_readin"Press enter or change if necessary: "$t_reset)" -e -i "$pi_pub_ip4" endp_ip
        fi
        e_choice="true"
        echo " "
elif [[ "${e_choice^^}" == "N" ]]; then
        e_choice="false"
else
        echo "$error_msg"
        exit 1
fi

# Add e_choice, e_ip_choice and endp_ip to reboot_helper
echo "e_choice $e_choice" >> $HOME/reboot_helper.txt 
echo "e_ip_choice $e_ip_choice" >> $HOME/reboot_helper.txt 
echo "endp_ip $endp_ip" >> $HOME/reboot_helper.txt 

echo $divider_line

# Ask for client name
echo "What would you like to name your first client? This will also be the name of the file
located in the /etc/wireguard/ folder. Can be anything you want, just don't use any spaces"
read -rp "$(echo -e $t_readin"Press enter or change the client name if desired: "$t_reset)" -e -i "client-1" client_name

# Add client_name to reboot_helper
echo "client_name $client_name" >> $HOME/reboot_helper.txt 

echo $divider_line

# Check if user wants to use persistent-keepalive
echo "If your VPN is going to be running under a NAT or firewalled connection
and you want to be able to access that network from anywhere, then I can include
the 'PersistentKeepalive = numOfSeconds' trait in the peer section of your first client's config file.
Generally, 25 seconds is enough and what is recommended by most people.

Would you like more detailed information on what 'PersistentKeepAlive' does?"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)"  -e -i "Y" pka_more_info_choice
if [[ "${pka_more_info_choice^^}" == "Y" ]]; then
	echo $divider_line
	echo -e "The following is paraphrasing WireGuard's official docs @ https://www.wireguard.com/quickstart/:
A primary goal of WireGuard is to be as stealthy and silent as possible. This is overall a good thing,
but due to reason's I'll explain, it can be problematic for those who have peers behind a stateful
firewall or NAT (router). Think of WireGuard as being one of those \"lazy texters\" that we all 
know - generally, WireGuard will only transmit data $t_bold"after"$t_reset it has received 
a request from a peer. So imagine communicating with your lazy friend that only replies after you contact them first. They're
still a good friend and you can still trust them, they just don't like texting so they do it as little
as possible. 

Okay, maybe not the best analogy, but hopefully you get the overall picture. 
So what does this have to do with PersistentKeepAlive? Well, that setting will tell the peer to send
data known as \"keepalive packets\" to the WireGuard server that basically just tells it 
\"Hey, I'm here, don't forget about me!\" By setting it to 25, we are telling the peer to remind WireGuard
that they are still active every 25 seconds. As WireGuard puts it, you should only need it if you are 
\"behind NAT or a firewall and you want to receive incoming connections long after network traffic has 
gone silent, this option will keep the \"connection\" open in the eyes of NAT.\""
	echo $divider_line
fi
echo "So, would you like to enable persistentKeepalive?"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)"  -e -i "Y" pka_choice

# Add pka_choice to reboot_helper
echo "pka_choice $pka_choice" >> $HOME/reboot_helper.txt 

echo $divider_line

# Ask if using mobile for client-1
echo "Will you be connecting to a mobile device as your client? If so, I can download and display a QR code for you to scan"
echo "Note: This is currently one of the most secure ways to connect to a mobile device."
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" mobile_choice

# Add mobile_choice to reboot_helper
echo "mobile_choice $mobile_choice" >> $HOME/reboot_helper.txt 

echo $divider_line

# Ask to enable wg-quick@wg0
echo "Would you like to automatically start WireGuard upon login? (typically 'yes')"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" auto_start_choice

# Add auto_start_choice to reboot_helper
echo "auto_start_choice $auto_start_choice" >> $HOME/reboot_helper.txt 


# Done with EAPHelper, create checkpoint and move on
echo "" > $DIR/EAPHelper_checkpoint.txt