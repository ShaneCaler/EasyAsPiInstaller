#!/bin/bash

# Grab necessary variables from reboot helper
if [[ -f $HOME/reboot_helper.txt ]]; then
	saved_table_choice="$(awk '/table_choice/{print $NF}' $HOME/reboot_helper.txt)"
	saved_firewall_choice="$(awk '/firewall_choice/{print $NF}' $HOME/reboot_helper.txt)"
	saved_int_addr_0="$(awk '/int_addr[0]/{print $NF}' $HOME/reboot_helper.txt)"
	saved_int_addr_2="$(awk '/int_addr[2]/{print $NF}' $HOME/reboot_helper.txt)"
	ipv6_choice="$(awk '/ipv6_choice/{print $NF}' $HOME/reboot_helper.txt)"
fi

# Check if pi-hole is already installed, if not, ask to install it and Unbound
if [[ ! -f $DIR/pihole_checkpoint.txt ]]; then
	echo "First things first: Would you like to install pi-hole after we set up WireGuard?
	According to the developers, 'the Pi-hole is a DNS sinkhole that protects your
	devices from unwanted content, without installing any client-side software.'"
	read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" pihole_choice
	if [[ "${pihole_choice^^}" == "Y"]]; then
		echo "Great, would you also like to setup Unbound to allow pi-hole to act as a 'recursive"
		echo "DNS server'? For info on what that is, please refer to the official pi-hole docs"
		echo "at https://docs.pi-hole.net/guides/unbound/"
		read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" unbound_choice
		if [[ "${unbound_choice^^}" != "Y" && "${unbound_choice^^}" != "N" ]]; then
			echo "$error_msg"
			exit 1
		fi

		# Add unbound choice to reboot_helper
		echo "unbound_choice $unbound_choice" >> $HOME/reboot_helper.txt 
		
		echo "Awesome, I'll keep that in mind for later! Let's go ahead and install Pi-Hole now,"
		echo "and we'll come back to Unbound after Wireguard is installed."
		sleep 2
		echo "Ready? Let's do this!"
		sleep 1
		echo $divider_line
		sleep 1
		. "$DIR/configure_pihole_unbound.sh" pihole
	else
		echo "Okay, we won't set up pi-hole. Feel free to do so yourself later!"
	fi
fi

echo "$divider_line"

# Temporarily change permissions to create keys (/etc/wireguard will be changed to 700 once the script finishes)
if [[ ! -d /etc/wireguard ]]; then
	sudo mkdir /etc/wireguard 
fi
sudo chmod 077 /etc/wireguard
cd /etc/wireguard
umask 077

# Ask if we should create an optional preshared key for extra security
echo "Alright, now it's time to generate your private and public keys for both
your server (the machine you're running now) and your first client. I'll take care of them for now,
but for future reference, they will be stored in: /etc/wireguard/ along with your server & client configuration files.

Now, before I do that, would you like to generate an optional preshared key to add another layer of security?"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" keychoice
if [[ "${keychoice^^}" == "Y" ]]; then
        wg genpsk > preshared
elif [[ "${keychoice^^}" == "N" ]]; then
        echo "Okay, moving on then..."
else
        echo "$error_msg"
        exit 1
fi

echo "$divider_line"

# generate server and client1 keys
wg genkey > server_private.key
wg pubkey > server_public.key < server_private.key
wg genkey > client1_private.key
wg pubkey > client1_public.key < client1_private.key

# Test to make sure at least 4 keys were created
echo "Okay, the keys should be made now but I'm going to check and make sure.
if you see 'KEYTEST IS OK' then you're ready to move on!"
sleep 2
key_test=$(ls -1 | wc -l)
if [ $key_test -gt 3 ]; then
	echo "KEYTEST IS OK"
else
	echo "KEYTEST FAILS - not all keys were created. Try manually adding them and restarting this installer."
	exit 1
fi
sleep 2

# Store keys into variables
serv_priv_key=$(cat /etc/wireguard/server_private.key)
serv_pub_key=$(cat /etc/wireguard/server_public.key)
client_priv_key=$(cat /etc/wireguard/client1_private.key)
client_pub_key=$(cat /etc/wireguard/client1_public.key)

#####################################
##### Begin server config setup #####
#####################################
echo "What would you like to name this WireGuard interface? Typically 'wg0'.
This will also be the name of the server config file located in /etc/wireguard/"
read -rp "$(echo -e $t_readin"Press enter or change if desired: "$t_reset)" -e -i "wg0" wg_intrfc
echo "$divider_line"

# Find user's private and public IP address + network interface
# credit to angristan@github for the private IPv4 address and interface calculations
pi_intrfc="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"

# TODO Check if private IPs and gateway are needed for anything
#pi_prv_ip4=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
#pi_prv_ip6=$(ip -6 addr show dev $pi_intrfc | grep 'fe80' | awk '{print $2}')
pi_pub_ip6=$(ip -6 addr show dev $pi_intrfc | grep 'inet6*' | awk '{print $2}' | sed '1!d' | cut -f1 -d"/")
pi_pub_ip4=$(host -4 myip.opendns.com resolver1.opendns.com | grep "myip.opendns.com has" | awk '{print $4}')
#pi_gateway=$(ip r | grep default | awk '{print $3}')

#echo "I have calculated your server's IPv4/IPv6 address, but you may change them now if they are incorrect for some reason.
#NOTE: This is different from the server's WireGuard address that we'll assign manually later. If everything looks OK, just hit 'enter'
#"
#read -rp "$(echo -e $t_readin"Replace with your server's IPv4 address (or just press enter): "$t_reset)" -e -i "$pi_prv_ip4" pi_prv_ip4
#echo " "

#if [[ "${ipv6_choice^^}" == "Y" ]]; then
#	echo "Since you chose to use IPv6, let's make sure that I have the right address for that as well."
#	read -rp "$(echo -e $t_readin"Replace with your public IPv6 address and subnet (or just press enter): "$t_reset)" -e -i "$pi_prv_ip6" pi_prv_ip6
#elif [[ "${ipv6_choice^^}" == "N" ]]; then
#	echo "Alright, moving on then!"
#fi

# Add variables to reboot_helper
#echo "pi_prv_ip4 $pi_prv_ip4" >> $HOME/reboot_helper.txt 
#echo "pi_prv_ip6 $pi_prv_ip6" >> $HOME/reboot_helper.txt 
#echo "pi_gateway $pi_gateway" >> $HOME/reboot_helper.txt 
echo "pi_intrfc $pi_intrfc" >> $HOME/reboot_helper.txt 
echo "pi_pub_ip4 $pi_pub_ip4" >> $HOME/reboot_helper.txt 

echo "$divider_line"

# Ask for internal IP address and subnet
echo "Create the internal server IPv4 or IPv6 addresses that you'd like to associate with 
WireGuard in the following format: IPv4: 10.24.42.1/24 or IPv6: 1337:abcd:24::1/64

TIPS:
Any four-digit group of zeroes for IPv6 may be shortened to just 0 or : or ::
IPv4 typically starts with 10 or 192, followed by two user-chosen numbers and ending in 1.
Avoid starting IPv6 with 2001 as they are often already registered.
IPv4 subnet: If you don't know what to use, try 24
Examples: 192.0.0.1/32 = handle a single IP address (192.0.0.1) OR
192.0.0.1/24 = handle 255 IP's from 192.0.0.1-255
Other common subnet numbers are 16, 8, or 0.
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

echo "$divider_line"

# Ask for listen port
echo "Type the listen port you'd like to use, commonly a number between 49152 through 65535
You can search https://www.iana.org/assignments/service-names-port-numbers for unassigned ports.
You will need to forward this port in your router, search google for your router model and
'port forwarding' for instructions on how to do so. Wireguard's default is 51820, 
so if in doubt you can go with that, though I'd recommend otherwise to have stronger security.
"
read -rp "$(echo -e $t_readin"Enter your desired port here: "$t_reset)" -e -i "51820" listen_port

# Add listen_port to reboot_helper
echo "listen_port $listen_port" >> $HOME/reboot_helper.txt 

echo "$divider_line"

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

echo "$divider_line"

# Ask if user wants to use Pi's DNS
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

echo "$divider_line"

# Ask for network interface
echo "I've determined that you're using '$pi_intrfc' as a network interface, but you may change it if needed.
Typically 'eth0' for ethernet or 'wlan0' for wireless (no quotes, using the number '0' - not the letter 'o')
"
read -rp "$(echo -e $t_readin"Enter your interface here, or just press 'enter': "$t_reset)" -e -i "$pi_intrfc" pi_intrfc

echo "$divider_line"

# Ask for server's allowed IP addresses for [peer] sections
echo "Please enter the 'allowed IPv4 Address and subnet' for the first peer on the server config file (you may add more later).
NOTE: 0.0.0.0/0 (IPv4) or ::/0 (IPv6) will forward all traffic through this interface!
If you don't use 0.0.0.0/0, then you will need to enter the previous IPv4 address but
replace the last digit with a higher number. (i.e. if you chose 10.24.42.1, enter 10.24.42.2)"
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

echo "$divider_line"

sleep 4
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

echo "$divider_line"

# Ask for clients allowed IP addresses
echo "Now we will do the same but for the client's 'allowed IPv4 address and subnet',
which should generally either be 0.0.0.0/0 (IPv4) or ::/0 (IPv6) to enable 'full tunneling',
or use the same pattern as the previously entered address(es) but with a 0 as the last digit
 of the address (i.e. 10.24.42.0/32 or 1337:abcd:24::/128)
"
client_allowed_ips=()
read -rp "$(echo -e $t_readin"Enter the client's allowed ipv4 address here: "$t_reset)" -e -i "10.24.42.0/24" client_allowed_ipv4
client_allowed_ips=(${client_allowed_ipv4})
if [[ "${ipv6_choice^^}" == "Y" ]]; then
        echo "Let's do the same for ipv6."
        read -rp "$(echo -e $t_readin"Enter the client's allowed ipv6 address here: "$t_reset)" -e -i "1337:abcd:24::/128" client_allowed_ipv6
        client_allowed_ips+=($client_allowed_ipv6)
fi

echo "$divider_line"

# Check if user wanted to use preshared key
if [[ "${keychoice^^}" == "Y" ]]; then
	if [[ ! -f /etc/wireguard/preshared ]]; then
		sudo chmod 077 /etc/wireguard
		cd /etc/wireguard
		wg genpsk > preshared
		pre_key="$(sudo cat /etc/wireguard/preshared)"
		sudo chmod 700 /etc/wireguard
	else
		pre_key="$(sudo cat /etc/wireguard/preshared)"
	fi
elif [[ "${keychoice^^}" == "N" ]]; then
    echo "Okay, moving on then..."
else
    echo "$error_msg"
    exit 1
fi

echo "$divider_line"

# Ask for endpoint
echo "Would you like to setup an endpoint for the first client config file?
Note: This generally must be accessible via the public internet (like a domain)
but if you want, I can grab your server's public IP using the 'Host' utility.
"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)"  -e -i "Y" e_choice
if [[ "${e_choice^^}" == "Y" ]]; then
        if [[ "${ipv6_choice^^}" == "Y" ]]; then
                echo "Since you're using IPv6, you can choose between the two for the endpoint."
                read -rp "$(echo -e $t_readin"Enter '4' for IPv4 or '6' for IPv6: "$t_reset)" -e -i "6" e_ip_choice
                if [[ "$e_ip_choice" == "6" ]]; then
                        read -rp "$(echo -e $t_readin"Press enter or change if necessary: "$t_reset)" -e -i "$pi_pub_ipv6" endp_ip
                elif [[ "$e_ip_choice" == "4" ]]; then
                        read -rp "$(echo -e $t_readin"Press enter or change if necessary: "$t_reset)" -e -i "$pi_pub_ipv4" endp_ip
                fi
        else
                read -rp "$(echo -e $t_readin"Press enter or change if necessary: "$t_reset)" -e -i "$pi_pub_ipv4" endp_ip
        fi
        e_choice="true"
        echo " "
elif [[ "${e_choice^^}" == "N" ]]; then
        e_choice="false"
else
        echo "$error_msg"
        exit 1
fi

echo "$divider_line
What would you like to name your first client? This will also be the name of the file
located in the /etc/wireguard/ folder. Can be anything you want, just don't use any spaces"
read -rp "$(echo -e $t_readin"Press enter or change the client name if desired: "$t_reset)" -e -i "client-1" client_name

echo "$divider_line"

# Configure post up and post down rules
if [[ "${saved_table_choice^^}" == "Y" ]]; then
	# TODO: Add nftables for post_up
	if [[ "${ipv6_choice^^}" == "Y" ]]; then
		post_up_tables="nft add rule ip filter FORWARD iifname \"$wg_intrfc\" counter accept; nft add rule ip nat POSTROUTING oifname \"$pi_intrfc\" counter masquerade; nft add rule ip6 filter FORWARD iifname \"$wg_intrfc\" counter accept; nft add rule ip6 nat POSTROUTING oifname \"$pi_intrfc\" counter masquerade"
		post_down_tables="nft delete rule filter FORWARD handle 11; nft drop rule ip nat POSTROUTING oifname \"$pi_intrfc\" counter masquerade; nft drop rule ip6 filter FORWARD iifname \"$wg_intrfc\" counter accept; nft drop rule ip6 nat POSTROUTING oifname \"$pi_intrfc\" counter masquerade"
	else
		post_up_tables="nft add rule ip filter FORWARD iifname \"$wg_intrfc\" counter accept; nft add rule ip nat POSTROUTING oifname \"$pi_intrfc\" counter masquerade"
		post_down_tables="nft delete rule filter FORWARD handle 11; nft drop rule ip nat POSTROUTING oifname \"$pi_intrfc\" counter masquerade"
	fi
	p_d_handle="$(sudo nft list table filter -a | grep 'iifname' | awk '{print $11}')"
else
	if [[ "${ipv6_choice^^}" == "Y" ]]; then
		post_up_tables="iptables -A FORWARD -i $wg_intrfc -j ACCEPT; iptables -A FORWARD -o $wg_intrfc -j ACCEPT; iptables -t nat -A POSTROUTING -o $pi_intrfc -j MASQUERADE; ip6tables -A FORWARD -i $wg_intrfc -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $pi_intrfc -j MASQUERADE"
		post_down_tables="iptables -D FORWARD -i $wg_intrfc -j ACCEPT; iptables -D FORWARD -o $wg_intrfc -j ACCEPT; iptables -t nat -D POSTROUTING -o $pi_intrfc -j MASQUERADE; ip6tables -D FORWARD -i $wg_intrfc -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $pi_intrfc -j MASQUERADE"
	else
		post_up_tables="iptables -A FORWARD -i $wg_intrfc -j ACCEPT; iptables -A FORWARD -o $wg_intrfc -j ACCEPT; iptables -t nat -A POSTROUTING -o $pi_intrfc -j MASQUERADE"
		post_down_tables="iptables -D FORWARD -i $wg_intrfc -j ACCEPT; iptables -D FORWARD -o $wg_intrfc -j ACCEPT; iptables -t nat -D POSTROUTING -o $pi_intrfc -j MASQUERADE"
	fi
fi

echo "$divider_line
Okay, I'm now going to create your server and client config files!
They will be located in /etc/wireguard - you will need to use sudo to open them
"

# TODO: allow for multiple clients to be added
# TODO: check if sudo sh is needed for cat
if [[ "${ipv6_choice^^}" == "Y" ]]; then
sudo cat <<EOF> /etc/wireguard/$wg_intrfc.conf
[Interface]
# Server1
Address = ${int_addr[0]}/${int_addr[1]}, ${int_addr[2]}/${int_addr[3]}
SaveConfig = $save_conf
ListenPort = $listen_port

PrivateKey = $serv_priv_key

PostUp = $post_up_tables
PostDown = $post_down_tables

[Peer]
# Client1
PublicKey = $client_pub_key
AllowedIPs = ${server_allowed_ips[0]}, ${server_allowed_ips[1]}

EOF

	# Setup client1.conf for IPv6
	# TODO try using endpoint IP for DNS
	sudo cat <<EOF> /etc/wireguard/$client_name.conf
[Interface]
# Client1
Address = ${server_allowed_ips[0]}, ${server_allowed_ips[1]}
ListenPort = $listen_port
PrivateKey = $client_priv_key
DNS = ${dns_addr[1]}

[Peer]
# Server1
PublicKey = $serv_pub_key
AllowedIPs = ${client_allowed_ips[0]}, ${client_allowed_ips[1]}

EOF

else
	# Setup configs for IPv4 only
	sudo cat <<EOF> /etc/wireguard/$wg_intrfc.conf
[Interface]
Address = ${int_addr[0]}/${int_addr[1]}
SaveConfig = $save_conf
ListenPort = $listen_port

PrivateKey = $serv_priv_key

PostUp = $post_up_tables
PostDown = $post_down_tables

[Peer]
#Client1
PublicKey = $client_pub_key
AllowedIPs = ${server_allowed_ips[0]}

EOF

	# Setup client1.conf for IPv4
	sudo cat <<EOF> /etc/wireguard/$client_name.conf
[Interface]
Address = ${server_allowed_ips[0]}
ListenPort = $listen_port
DNS = ${dns_addr[0]}

PrivateKey = $client_priv_key


[Peer]
# Server1
PublicKey = $serv_pub_key
AllowedIPs = ${client_allowed_ips[0]}

EOF

fi

# Check if user wants to use endpoint on their client config
if [ "$e_choice" == "true" ]; then
	if [[ "$e_ip_choice" == "6" ]]; then
        sudo sh -c "echo \"Endpoint = $endp_ip:$listen_port\" >> /etc/wireguard/$client_name.conf"
	else
		sudo sh -c "echo \"Endpoint = $endp_ip:$listen_port\" >> /etc/wireguard/$client_name.conf"
        fi
fi
if [[ "${keychoice^^}" == "Y" ]]; then
	sudo sh -c "echo \"PresharedKey = $pre_key\" >> /etc/wireguard/$client_name.conf"
	sudo sh -c "echo \"PresharedKey = $pre_key\" >> /etc/wireguard/$wg_intrfc.conf"
fi

# Check if user wants to use presistent-keepalive
echo "If your VPN is going to be running under a NAT or firewalled connection
and you want to be able to access that network from anywhere, then I can include
the 'PersistentKeepalive = numOfSeconds' trait in the peer section of your first client's config file.
Generally, 25 seconds is enough and what is recommended by most people.
Would you like more detailed information on what 'PersistentKeepAlive' does?"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)"  -e -i "Y" pka_more_info_choice
if [[ "${pka_more_info_choice^^}" == "Y" ]]; then
	echo -e "The following is paraphrasing WireGuard's official docs @ https://www.wireguard.com/quickstart/:
A primary goal of WireGuard is to be as stealthy and silent as possible. This is overall a good thing,
but due to reason's I'll explain, it can be problematic for those who have peers behind a stateful
firewall or NAT (router). Think of WireGuard as being one of those 'lazy texters' that we all 
know - generally, WireGuard will only transmit data $t_bold"after"$t_reset it has received 
a request from a peer. So imagine communicating with your lazy friend that only replies after you contact them first. They're
still a good friend and you can still trust them, they just don't like texting so they do it as little
as possible. 

Okay, maybe not the best analogy, but hopefully you get the overall picture. 
So what does this have to do with PersistentKeepAlive? Well, that setting will tell the peer to send
data known as \"keepalive packets\" to the WireGuard server that basically just tells it 
\"Hey, I'm here, don't forget about me!\" By setting it to 25, we are telling the peer to remind WireGuard
that they are still active every 25 seconds. As WireGuard puts it, you should only need it if you are 
\"$t_bold"behind NAT or a firewall and you want to receive incoming connections long after network traffic has 
gone silent, this option will keep the 'connection' open in the eyes of NAT."$t_reset\""

	echo "$divider_line"
	read -rp "$(echo -e $t_readin"Whew! Okay, that was a lot. Press enter whenever you're ready to move on: "$t_reset)" -e -i "" pka_move_forward
fi

echo "$divider_line"
echo "Alright, so would you like to enable persistentKeepalive?"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)"  -e -i "Y" pka_choice

# save pka_choice to use in configure_firewall
echo "pka_choice $pka_choice" >> $HOME/reboot_helper.txt 

if [[ "${pka_choice^^}" == "Y" ]]; then
	read -rp "$(echo -e $t_readin"What number of seconds would you like to use? "$t_reset)" -e -i "25" pka_num 
	echo "Okay, I'll go ahead and set that for you."
	sudo sh -c "echo 'PersistentKeepalive = $pka_num' >> /etc/wireguard/$client_name.conf"
elif [[ "${pka_choice^^}" == "N" ]]; then
	echo "Alright, moving on then!"
else
	echo "$error_msg"
fi

echo "$divider_line
Okay, I've created the config files for your server and first client!
"

sleep 2

echo "$divider_line"

echo -e $t_bold"We're done setting up WireGuard on the server-side, so lets start it up!
(I'll pause for a few seconds in case you want to read the output from starting the server)
"$t_reset

# Start the server!
sudo wg-quick up $wg_intrfc
sudo wg
# Sleep for a few seconds to read output
sleep 5

echo "$divider_line"

# Ask if using mobile
echo "Will you be connecting to a mobile device? If so, I can download and display a QR code for you to scan"
echo "Note: This is currently one of the most secure ways to connect to a mobile device."
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" m_choice
if [[ "${m_choice^^}" == "Y" ]]; then
	sudo apt install qrencode -y
	sudo sh -c "qrencode -t ansiutf8 < /etc/wireguard/$client_name.conf"
elif [[ "${m_choice^^}" == "N" ]]; then
	echo "Please refer to the github readme or other online sources to configure communications"
	echo "with other sources. This installer will create one client script, but the rest is up to you!"
else
	echo "$error_msg"
	exit 1
fi

echo "$divider_line"

sudo sysctl --system
# Ask to enable wg-quick@wg0
echo "Would you like to automatically start WireGuard upon login? (typically 'yes')"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" auto_choice
if [[ "${auto_choice^^}" == "Y" ]]; then
	sudo sh -c "systemctl enable wg-quick@$wg_intrfc"
	sudo sh -c "systemctl start wg-quick@$wg_intrfc"
elif [[ "${auto_choice^^}" == "Y" ]]; then
	echo "Okay, if you want to enable auto-start at another time, the command is: "
	echo "\"sudo systemctl enable wg-quick@$wg_intrfc\""
else
	echo "$error_msg"
	exit 1
fi

# Restore permissions
cd $DIR
sudo chown -R root:root /etc/wireguard/wg0.conf
sudo chmod -R og-rwx /etc/wireguard/wg0.conf
sudo chmod 700 /etc/wireguard


# Leave configure_wireguard and create checkpoint.
echo "" > $DIR/wg_config_checkpoint.txt

