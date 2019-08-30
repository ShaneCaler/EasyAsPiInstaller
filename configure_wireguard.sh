#!/bin/bash

echo "
-----------------------------------------------------------------------------------------
Alright, first things first: Would you like to install pi-hole after we set up WireGuard?
According to the developers, 'the Pi-holeÂis a DNS sinkhole that protects your
devices from unwanted content, without installing any client-side software.'"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" pihole_choice
if [[ "${pihole_choice^^}" == "Y" ]]; then
	echo "Great, would you also like to setup Unbound to allow pi-hole to act as a 'recursive"
	echo "DNS server'? For info on what that is, please refer to the official pi-hole docs"
	echo "at https://docs.pi-hole.net/guides/unbound/"
	read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" unb_choice
	if [[ "${unb_choice^^}" != "Y" && "${unb_choice^^}" != "N" ]]; then
		echo "$error_msg"
		exit 1
	fi
	echo "Awesome, I'll keep that in mind for later!"
fi

echo "
----------------------------------------------------------------------------------------
"

# Temporarily change permissions to create keys (/etc/wireguard will be changed to 700 once the script finishes)
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
echo "
---------------------------------------------------------------------------------------
"
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
client_priv_key=$(cat /etc/wireguard/client_private.key)
serv_pub_key=$(cat /etc/wireguard/client_public.key)

#####################################
##### Begin server config setup #####
#####################################
echo "What would you like to name this WireGuard interface? Typically 'wg0'.
This will also be the name of the server config file located in /etc/wireguard/"
read -rp "$(echo -e $t_readin"Press enter or change if desired: "$t_reset)" -e -i "$wg0" wg_intrfc
echo "
---------------------------------------------------------------------------------------------------------------------------
"
# Find user's private and public IP address + network interface
# credit to angristan@github for the private IPv4 address and interface calculations
pi_intrfc="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
pi_prv_ip4=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
pi_prv_ip6=$(ip -6 addr show dev $pi_intrfc | grep 'fe80' | awk '{print $2}')
pi_pub_ip6=$(ip -6 addr show dev $pi_intrfc | grep 'inet6*' | awk '{print $2}' | sed '1!d' | cut -f1 -d"/")
pi_pub_ip4=$(host -4 myip.opendns.com resolver1.opendns.com | grep "myip.opendns.com has" | awk '{print $4}')
pi_gateway=$(ip r | grep default | awk '{print $3}')

# Add variables to reboot_helper
echo "pi_intrfc $pi_intrfc" >> $HOME/reboot_helper.txt 
echo "pi_pub_ip4 $pi_pub_ip4" >> $HOME/reboot_helper.txt 
echo "pi_gateway $pi_gateway" >> $HOME/reboot_helper.txt 

echo "I have calculated your server's IPv4/IPv6 address, but you may change them now if they are incorrect for some reason.
NOTE: This is different from the server's WireGuard address that we'll assign manually later. If everything looks OK, just hit 'enter'
"
read -rp "$(echo -e $t_readin"Replace with your server's IPv4 address and subnet (or just press enter): "$t_reset)" -e -i "$pi_prv_ip4" pi_prv_ip4
echo " "
# Grab ipv6_choice from reboot_helper
ipv6_choice="$(awk '/ipv6_choice/{print $NF}' $HOME/reboot_helper.txt)"
if [[ "${ipv6_choice^^}" == "Y" ]]; then
	echo "Since you chose to use IPv6, let's make sure that I have the right address for that as well."
	read -rp "$(echo -e $t_readin"Replace with your public IPv6 address and subnet (or just press enter): "$t_reset)" -e -i "$pi_prv_ip6" pi_prv_ip6
elif [[ "${ipv6_choice^^}" == "N" ]]; then
	echo "Alright, moving on then!"
fi
# Add variables to reboot_helper
echo "pi_prv_ip4 $pi_prv_ip4" >> $HOME/reboot_helper.txt 
echo "pi_prv_ip6 $pi_prv_ip6" >> $HOME/reboot_helper.txt 

echo "
---------------------------------------------------------------------------------------------------------------------------
"
# Ask for internal IP address and subnet
echo "Create the internal server IPv4 or IPv6 addresses that you'd
like to associate with WireGuard in the following format: IPv4: 10.24.42.1/24 or IPv6: 1337:abcd:24::1/64
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
	IFS='/' read -rp "$(echo -e $t_readin"Enter internal IPv6 address in the format given: "$t_reseet)" -e -i "1337:abcd:24::1/64" -a int_addr_temp
	int_addr+=( ${int_addr_temp[@]} )
fi
# Add int_addr to reboot_helper 
echo "int_addr[0] ${int_addr[0]}" >> $HOME/reboot_helper.txt 
echo "int_addr[1] ${int_addr[0]}" >> $HOME/reboot_helper.txt 
echo "int_addr[2] ${int_addr[0]}" >> $HOME/reboot_helper.txt 
echo "int_addr[3] ${int_addr[0]}" >> $HOME/reboot_helper.txt 

echo "
---------------------------------------------------------------------------------------------------------------------------
"
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

echo "
---------------------------------------------------------------------------------------------------------------------------
"
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
echo "
---------------------------------------------------------------------------------------------------------------------------
"
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
	Example: $pi_pub_ip4,1.1.1.1"
	read -rp "$(echo -e $t_readin"Enter your secondary (IPv4) DNS provider or just press 'Enter': "$t_reset)" -e -i "$pi_prv_ip4" dns_v4
	dns_addr+=($dns_v4)
	if [ "${ipv6_choice^^}" == "Y" ]];
		echo "Let's do the same for ipv6."
		read -rp "$(echo -e $t_readin"Enter your secondary DNS provider or just press 'Enter': "$t_reset)" -e -i "$pi_prv_ip6" dns_v6
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
echo "
-------------------------------------------------------------------------------------------------------------
"
# Ask for network interface
echo "I've determined that you're using '$pi_intrfc' as a network interface, but you may change it if needed.
Typically 'eth0' for ethernet or 'wlan0' for wireless (no quotes, using the number '0' - not the letter 'o')
"
read -rp "$(echo -e $t_readin"Enter your interface here, or just press 'enter': "$t_reset)" -e -i "$pi_intrfc" pi_intrfc
echo "
-------------------------------------------------------------------------------------------------------------
"
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
this source IP address to the VPN server. Itâ€™s also important to know that there are no peers
with the same AllowedIPs addresses/networks inside the same configuration file. If this would be the case,
the server would not know to which peer the server has to send packages matching multiple peers with the same network configured."
fi
echo "
----------------------------------------------------------------------------------------------------------------
"
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
echo "
------------------------------------------------------------------------------------------------------------------
"
# Ask for clients allowed IP addresses
echo "Now we will do the same but for the client's 'allowed IPv4 address and subnet',
which should generally either be 0.0.0.0/0 (IPv4) or ::/0 (IPv6) to enable 'full tunneling',
or use the same pattern as the previously entered address(es) but with a 0 as the last digit
 of the address (i.e. 10.24.42.0/32 or 1337:abcd:24::/128)
"
client_allowed_ips=()
read -rp "$(echo -e $t_readin"Enter the client's allowed ipv4 address here: "$t_reset)" -e -i "10.24.42.0/32" client_allowed_ipv4
client_allowed_ips=(${client_allowed_ipv4})
if [[ "${ipv6_choice^^}" == "Y" ]]; then
        echo "Let's do the same for ipv6."
        read -rp "$(echo -e $t_readin"Enter the client's allowed ipv6 address here: "$t_reset)" -e -i "1337:abcd:24::/128" client_allowed_ipv6
        client_allowed_ips+=($client_allowed_ipv6)
fi
echo "
--------------------------------------------------------------------------------------------------------------------
"
# Ask for preshared key
echo "Would you like to include a preshared key for added (optional) security?"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)"  -e -i "Y" p_choice
if [[ "${p_choice^^}" == "Y" ]]; then
        p_choice="true"
	if [ -f /etc/wireguard/preshared ]; then
		sudo chmod 077 etc/wireguard
		cd /etc/wireguard
		wg genpsk > preshared
		pre_key="$(sudo cat /etc/wireguard/preshared)"
		sudo chmod 700 etc/wireguard
	else
		pre_key="$(sudo cat /etc/wireguard/preshared)"
else if [[ "{$p_choice^^}" == "N" ]]; then
        p_choice="false"
	echo "Okay, moving on then!"
else
        echo "$error_msg"
        exit 1
fi
echo "
---------------------------------------------------------------------------------------------------------------------
"
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

echo "
---------------------------------------------------------------------------------------------------------------------
What would you like to name your first client? This will also be the name of the file
located in the /etc/wireguard/ folder. Can be anything you want, just don't use any spaces"
read -rp "$(echo -e $t_readin"Press enter or change the client name if desired: "$t_reset)" -e -i "client-1" client_name

echo "
----------------------------------------------------------------------------------------------------------------------
Finally, would you like to use legacy iptables (default) or the newer nftables to
configure this server's firewall?
NOTE: This feature is still experimental, if you choose nftables please review
this script's code and make sure that it looks OK. I will link the resources that
I used to create the firewall commands in the references section of the github readme.
"
if [[ "${table_choice^^}" == "Y" ]]; then
	# TODO: Add nftables for post_up
	post_up_tables="nft add rule ip filter FORWARD iifname "$wg_intrfc" counter accept; nft add rule ip nat POSTROUTING oifname "$pi_intrfc" counter masquerade; nft add rule ip6 filter FORWARD iifname "$wg_intrfc" counter accept; nft add rule ip6 nat POSTROUTING oifname "$pi_intrfc" counter masquerade"
	
	p_d_handle="$(sudo nft list table filter -a | grep 'iifname' | awk '{print $11}')"
	post_down_tables="nft delete rule filter FORWARD handle 11; nft drop rule ip nat POSTROUTING oifname "$pi_intrfc" counter masquerade; nft drop rule ip6 filter FORWARD iifname "$wg_intrfc" counter accept; nft drop rule ip6 nat POSTROUTING oifname "$pi_intrfc" counter masquerade"
elif [[ "${table_choice^^}" == "N" ]]; then
	post_up_tables="iptables -A FORWARD -i $wg_intrfc -j ACCEPT; iptables -t nat -A POSTROUTING -o $pi_intrfc -j MASQUERADE; ip6tables -A FORWARD -i $wg_intrfc -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $pi_intrfc -j MASQUERADE"
	post_down_tables="iptables -D FORWARD -i $wg_intrfc -j ACCEPT; iptables -t nat -D POSTROUTING -o $pi_intrfc -j MASQUERADE; ip6tables -D FORWARD -i $wg_intrfc -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $pi_intrfc -j MASQUERADE"
else
	echo "Something went wrong setting up the server's PostUp and PostDown rules!"
fi
echo "
-----------------------------------------------------------------------------------------------------------------------
Okay, I'm now going to create your server and client config files!
They will be located in /etc/wireguard - you will need to be sudo to open them
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
sudo cat <<EOF> etc/wireguard/$client_name.conf
[Interface]
# Client1
Address = ${server_allowed_ips[0]}, ${server_allowed_ips[1]}
SaveConfig = $save_conf
ListenPort = $listen_port
PrivateKey = $client_priv_key
DNS = ${dns_addr[0]},${dns_addr[1]}

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
DNS = ${dns_addr[0]}

EOF

# Setup client1.conf for IPv4
sudo cat <<EOF> etc/wireguard/$client_name.conf
[Interface]
Address = ${server_allowed_ips[0]}
SaveConfig = $save_conf
ListenPort = $listen_port
PrivateKey = $client_priv_key
DNS = ${dns_addr[0]}

[Peer]
# Server1
PublicKey = $serv_pub_key
AllowedIPs = ${client_allowed_ips[0]}

EOF

fi

# Check if user wants to use endpoint on their client config
if [ "$e_choice" == "true" ]; then
	if [[ "$e_ip_choice" == "6" ]]; then
        	echo "Endpoint = $serv_pub_ipv6:$listen_port" >> /etc/wireguard/$client_name.conf
	else
		echo "Endpoint = $serv_pub_ipv4:$listen_port" >> /etc/wireguard/$client_name.conf
        fi
fi
if [ "$p_choice" == "true" ]; then
	echo "PresharedKey = $pre_key" >> /etc/wireguard/$client_name.conf
	echo "PresharedKey = $pre_key" >> /etc/wireguard/$wg_intrfc.conf
fi

# Check if user wants to use presistent-keepalive
echo "If your VPN is going to be running under a NAT or firewalled connection
and you want to be able to access that network from anywhere, then I can include
the 'PersistentKeepalive = numOfSeconds' trait in the peer section of your first client's config file.
Generally, 25 seconds is enough and what is recommended by most people.
Would you like more detailed information on what 'PersistentKeepAlive' does?"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)"  -e -i "Y" pka_more_info_choice
if [[ "${pka_more_info_choice^^}" == "Y" ]]; then
	echo "The following is paraphrasing WireGuard's official docs @ https://www.wireguard.com/quickstart/:
A primary goal of WireGuard is to be as stealthy and silent as possible. This is overall a good thing,
but due to reason's I'll explain, it can be problematic for those who have peers behind a stateful
firewall or NAT (router). Think of WireGuard as being one of those 'lazy texters' that we all 
know and love - generally, WireGuard will only transmit data ($t_bold)after($t_reset) it has received 
a request from a peer. So imagine your lazy friend that only replies once you contact them first. They're
still a good friend and you can still trust them, they just don't like texting so they do it as little
as possible. Okay, maybe not the best analogy, but hopefully you get the overall picture. 
So what does this have to do with PersistentKeepAlive? Well, that setting will tell the peer to send
data known as 'keepalive packets' to the WireGuard server that basically just tells it 
'Hey, I'm here, don't forget about me!' By setting it to 25, we are telling the peer to remind WireGuard
that they are still active every 25 seconds. As WireGuard puts it, you should only need it if you are 
'behind NAT or a firewall and you want to receive incoming connections long after network traffic has 
gone silent, this option will keep the 'connection' open in the eyes of NAT.'"
	read -rp "$(echo -e $t_readin"Whew! Okay, that was a lot. Press enter whenever you're ready to move on: "$t_reset)" -e -i "" pka_move_forward
fi
echo "Alright, so would you like to enable persistentKeepalive?"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)"  -e -i "Y" pka_choice
if [[ "${pka_choice^^}" == "Y" ]]; then
	read -rp "$(echo -e $t_readin"What number of seconds would you like to use? "$t_reset)" -e -i "25" pka_num 
	echo "Okay, I'll go ahead and set that for you."
	echo "PersistentKeepalive = $pka_num" >> /etc/wireguard/$client_name.conf
elif [[ "${pka_choice^^}" == "N" ]]; then
	echo "Alright, moving on then!"
else
	echo "$error_msg"
fi

echo "
-----------------------------------------------------------------------------------
Okay, I've created the config files for your server and first client!
Now would you like me to set up some additional firewall rules?
If yes, I'd suggest reading over the code to make sure they work in your situation.
If you'd like to manage them yourself, just choose no."
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)"  -e -i "Y" add_fw_choice
if [[ "${add_fw_choice^^}" == "Y" ]]; then
	. "$DIR/configure_firewall.sh" phase2
elif [[ "${add_fw_choice^^}" == "N" ]]; then
	echo "Alright, lets move on then!"
else
	echo "$error_msg"
	exit 1
fi


echo -e  $t_bold"
--------------------------------------------------------------------------------------------------------------
We're done setting up WireGuard on the server-side, so lets start it up!
(I'll pause for a few seconds in case you want to read the output from starting the server)
"$t_reset

# Start the server!
sudo wg-quick up wg0
sudo wg
# Sleep for a few seconds to read output
sleep 5
echo "
--------------------------------------------------------------------------------------------------------------
"
# Ask if using mobile
echo "Will you be connecting to a mobile device? If so, I can download and display a QR code for you to scan"
echo "Note: This is currently one of the most secure ways to connect to a mobile device."
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" m_choice
if [[ "${m_choice^^}" == "Y" ]]; then
    sudo apt install qrencode -y
	qrencode -t ansiutf8 < /etc/wireguard/$client_name.conf
else if [[ "${m_choice^^}" == "N" ]]; then
    echo "Please refer to the github readme or other online sources to configure communications"
	echo "with other sources. This installer will create one client script, but the rest is up to you!"
else
    echo "$error_msg"
    exit 1
fi

echo "
-------------------------------------------------------------------------------------------------------------
"
sudo sysctl --system
# Ask to enable wg-quick@wg0
echo "Would you like to automatically start WireGuard upon login? (typically 'yes')"
read -rp "$(echo -e $t_readin""$prompt" "$t_reset)" -e -i "Y" auto_choice
if [[ "${auto_choice^^}" == "Y" ]]; then
	sudo systemctl start wg-quick@$wg_intrfc
	sudo systemctl enable wg-quick@$wg_intrfc
else if [[ "${auto_choice^^}" == "Y" ]]; then
	echo "Okay, if you want to enable auto-start at another time, the command is: "
	echo "'sudo systemctl enable wg-quick@wg0'"
else
	echo "$error_msg"
	exit 1
fi

# Restore permissions
cd $DIR
sudo chown -R root:root /etc/wireguard/wg0.conf
sudo chmod -R og-rwx /etc/wireguard/wg0.conf
sudo chmod 700 /etc/wireguard

# Install pi-hole
install_pi-hole(){
	# Install resolvconf before pi-hole
	sudo apt install resolveconf -y

	echo -e $t_important"---------IMPORTANT!! PLEASE READ!!---------"$t_reset
	echo -e $t_important"---------IMPORTANT!! PLEASE READ!!---------"$t_reset
	echo "You will now be redirected the pi-hole installer. Please take note of the following"
	echo "information, as you'll be required to manually input values. I'll take you through the 9 steps now:"
	echo -e "$t_bold"Step 1:"$t_reset Press '<OK>' until you reach the 'Choose An Interface' screen."
	echo "	- Select the WireGuard interface you chose: $wg_intrfc"
	echo -e "$t_bold"Step 2:"$t_reset Set the Upstream DNS Provider to whomever you want, if you plan on"
	echo "using Unbound, this setting doesn't matter much, so just choose anything."
	echo  -e "$t_bold"Step 3:"$t_reset Select the 'Block Lists' to enable - I suggest enabling them all."
	echo  -e "$t_bold"Step 4:"$t_reset Choose IPv4 or both if you chose to use IPv6 earlier."
	echo  -e "$t_bold"Step 5:"$t_reset Static addresses should be: "
	echo "	- ${int_addr[0]}/${int_addr[1]} for IPv4 or ${int_addr[2]}/${int_addr[3]} for IPv6."
	echo "	- Gateway is the same address as above, but with no subnet value (i.e. ${int_addr[0]}"
	echo  -e "$t_bold"Step 6:"$t_reset I highly recommend installing the web admin interface!"
	echo  -e "$t_bold"Step 7:"$t_reset If you don't already have a webserver installed (most people won't)"
	echo "Then I recommend installing the web server (lighttpd) as well."
	echo  -e "$t_bold"Step 8:"$t_reset Again, go with what pi-hole recommends and turn logging on, unless"
	echo "you have a specific reason not to."
	echo  -e "$t_bold"Step 9:"$t_reset If you want less clutter in your logs you can choose one of these options, "
	echo "But to get the most out of the pi-hole I think it's best to Show Everything."
	echo "And thats it for pi-hole!"
	echo "----------------------------------------------------------------------------------------------------"
	echo "NOTE: This installation method uses the command: # sudo curl -ssL https://instal.pi-hole.net | bash"
        echo "It is generally bad practice to curl into bash, but in this case we know that"
        echo "the script is from a reputable source. It still couldn't hurt to look over the code yourself"
        echo "if you're concered or interested!"
	echo -e $t_important"IMPORTANT: YOU MUST MANUALLY REBOOT ONCE PI-HOLE IS FINISHED INSTALLING"$t_reset
	echo -e $t_important"IF AUTOLOGIN IS ENABLED, THIS SCRIPT SHOULD PICK BACK UP WHERE WE LEFT OFF"$t_reset
	echo "I recommend screenshotting these instructions if you are using SSH, "
	echo "Or just take a picture with your phone. Good luck and I'll see you once you're done!"
	read -rp "$(echo -e $t_readin"Type Y whenever you're ready to start the pi-hole installation: "$t_reset)" -e -i "" p_start_choice
	if [[ "{p_start_choice^^}" == "Y"]]; then
echo '
				 __
		 _(\    |@@|
		(__/\__ \--/ __         See You Soon!
		   \___|----|  |   __
			   \ }{ /\ )_ / _\
			   /\__/\ \__O (__
			  (--/\--)    \__/
			  _)(  )(_
			 `---  ---`

'
		# Create checkpoint file
		echo "pi-hole checkpoint" > $HOME/pihole_checkpoint.txt
		sleep 3
		sudo curl -ssL https://install.pi-hole.net | bash
	else
		echo "Okay, here is the command again to install pi-hole yourself if you choose to do so:"
		echo "# sudo curl -ssL https://instal.pi-hole.net | bash"
		echo "There are also plenty of resources online, some of which I will link in the references section."
	fi
}

install_unbound() {
	# Install unbound to setup pi-hole as a recursive DNS server
	sudo apt install unbound

	# Install current root hints file
	echo -e $t_important"----IMPORTANT----"
	echo -e "You will need to run the following commands every six months or so."
	echo -e "See Pi-hole docs for more info @ https://docs.pi-hole.net/guides/unbound/"
	echo -e "# wget -O root.hints https://www.internic.net/domain/named.root"
	echo -e "# sudo mv root.hints /var/lib/unbound/"$t_reset

	wget -O root.hints https://www.internic.net/domain/named.root
	sudo mv root.hints /var/lib/unbound/

	# Determine unbound variable values
	if [[ "${ipv6_choice^^}" == "Y" ]]; then
		unb_ipv6="yes"
	else
		unb_ipv6="no"
	fi
	
	modded_ip=$(echo "${int_addr[0]}" | cut -f -3 -d'.')

	# Configure Unbound
	sudo cat <<-EOF> /etc/unbound/unbound.conf.d/pi-hole.conf
	server:
	    # If no logfile is specified, syslog is used
	    # logfile: "/var/log/unbound/unbound.log"
	    verbosity: 1

	    port: 5353
	    do-ip4: yes
	    do-udp: yes
	    do-tcp: yes

	    # May be set to yes if you have IPv6 connectivity
	    do-ip6: $unb_ipv6

	    # Use this only when you downloaded the list of primary root servers!
	    root-hints: "/var/lib/unbound/root.hints"

	    # Respond to DNS requests on all interfaces
	    interface: 0.0.0.0
	    max-udp-size: 3072

	    # IPs authorised to access the DNS Server
	    access-control: 0.0.0.0/0                 refuse
	    access-control: 127.0.0.1                 allow
	    access-control: $modded_ip.0/24             allow

	    # Hide DNS Server info
	    hide-identity: yes
	    hide-version: yes

	    # Trust glue only if it is within the servers authority
	    harden-glue: yes

	    # Require DNSSEC data for trust-anchored zones, if such data is absent, the zone becomes BOGUS
	    harden-dnssec-stripped: yes
	    harden-referral-path: yes

	    # Add an unwanted reply threshold to clean the cache and avoid, when possible, DNS poisoning
	    unwanted-reply-threshold: 10000000

	    # Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
	    # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
	    use-caps-for-id: no

	    # Reduce EDNS reassembly buffer size.
	    # Suggested by the unbound man page to reduce fragmentation reassembly problems
	    edns-buffer-size: 1472

	    # TTL bounds for cache
	    cache-min-ttl: 3600
	    cache-max-ttl: 86400

	    # Perform prefetching of close to expired message cache entries
	    # This only applies to domains that have been frequently queried
	    prefetch: yes
	    prefetch-key: yes

	    # One thread should be sufficient, can be increased on beefy machines.
	    # In reality for most users running on small networks or on a single
	    # machine it should be unnecessary to seek performance enhancement by increasing num-threads above 1.
	    num-threads: 1

	    # Ensure kernel buffer is large enough to not lose messages in traffic spikes
	    so-rcvbuf: 1m

	    # Ensure privacy of local IP ranges
	    private-address: 192.168.0.0/16
	    private-address: 169.254.0.0/16
	    private-address: 172.16.0.0/12
	    private-address: 10.0.0.0/8
	    private-address: fd00::/8
	    private-address: fe80::/10

	EOF

# Create unbound checkpoint
echo "" > $DIR/unbound_checkpoint.txt

# Reboot to finish installation
sudo shutdown -r now

}

# Check if user just wants pi-hole or unbound, but not both
if [[ "${pihole_choice^^}" == "Y" && ! -f $DIR/pihole_checkpoint.txt ]]; then
	install_pihole
	echo "Alright, we've installed pi-hole! Let's check to see if it works by using the 'host' command."
	echo "First, I will run it against the server host using Pi-hole's DNS to verify that it is active,"
	echo "And then I'll run it against 'pagead2.googlesyndication.com' to verify that ads are being served"
	echo "By the Pi-hole. You should see the custom IP that you set earlier next to 'has address'"
	if [[ "{ipv6_choice^^}" == "Y" ]]; then
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
if [[ "${unb_choice^^}" == "Y" && ! -f $DIR/unbound_checkpoint.txt]]; then
	install_unbound
fi

# Leave configure_wireguard and create checkpoint.
echo "" > $DIR/wg_config_checkpoint.txt

# if [[ ! -f $DIR/unbound_checkpoint.txt && -f $DIR/pihole_checkpoint.txt ]]; then
	# # Done, with no unbound
# elif [[ -f $DIR/pihole_checkpoint.txt && -f $DIR/unbound_checkpoint.txt ]]; then
	# # Done, with pihole and unbound installed
	# echo "Done! Now I'll start Unbound and use the 'dig pi-hole.net @127.0.0.1 -p 5353'"
	# echo "command to check if it's working. I'll run this three times with different options. "
	# echo "For the first, the 'status' parameter should be equal to 'NOERROR'. This verifies that DNS is working."
	# echo "I'll wait for your input at the end so you can have time to review the results."
	# sleep 3
	# sudo service unbound start
	# # need timeout?
	# dig pi-hole.net @127.0.0.1 -p 5353
	# sleep 2
	# echo "Now, this next test should show 'SERVFAIL' for the 'status' parameter."
	# echo "This verifies that DNSSEC is established, as we are running the dig command"
	# echo "against 'sigfail.verteiltesysteme.net' which replicates a website that has a failed signature."
	# echo "Note: This method of DNSSEC test validation is provided by: https://dnssec.vs.uni-due.de"
	# sleep 3
	# dig sigfail.verteiltesysteme.net @127.0.0.1 -p 5353
	# sleep 2
	# echo "Finally, just to make sure that everything's working, we'll run dig against "
	# echo "the domain 'sigok.verteiltesysteme.net', which as you can guess should return"
	# echo "the status value of 'NOERROR'"
	# sleep 3
	# dig sigok.verteiltesysteme.net @127.0.0.1 -p 5353
	# sleep 2
	# read -rp "Press enter whenever you are ready to move forward: " -e -i "" move_forward_choice
	# sleep 1
	# echo "Okay, there's one last thing you need to do before Unbound is good-to-go, and unfortunately,"
	# echo "you're on your own with this one! You'll need to open up a web browser on your phone or another device"
	# echo "and visit your Pi-hole admin dashboard that you created in the Pi-hole installation process."
	# echo "From what I can tell, it should be http://"${int_addr[0]}"/admin for IPv4,"
	# echo "or http://"${int_addr[2]}"/admin for IPv6, but if you changed it to something else then use that!"
	# echo "Once logged in, click the 'Settings' button on the left and then navigate to the 'DNS' tab on that page."
	# echo "You'll see two sections labeled 'Upstream DNS Servers', don't touch any of them other than the field that "
	# echo "is labeled 'Custom 1' for IPv4 users or both 'Custom 1' and 'Custom 3' for IPv6 users. In 'Custom 1', "
	# echo "Enter '127.0.0.1#5353' and if you're using IPv6 then also enter '::1#5353' into 'Custom 3'."
	# echo "Finally, underneath the box that you just edited there is a section labeled 'Interface Listening Behavior.'"
	# echo "Set this to only listen to the wireguard interface, in your case: $wg_intrfc"
# elif [[ "${pihole_choice^^}" == "N" ]]; then
	# # Done, with no pihole or unbound
# else
	# # Done - not sure what happened here?
# fi

# # Delete auto-start entry
# #sudo sh -c "sed -i '/wireguard/d' /etc/profile"
# sudo sh -c "sed -i '/EasyAsPiInstaller.sh/d' /etc/profile"

