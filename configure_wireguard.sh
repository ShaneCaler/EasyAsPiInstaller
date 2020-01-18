#!/bin/bash

# Grab necessary variables from reboot helper
if [[ -f $HOME/reboot_helper.txt ]]; then
	DIR="$(awk '/DIR/{print $NF}' $HOME/reboot_helper.txt)"
	table_choice="$(awk '/table_choice/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[0]="$(awk '/int_addr[0]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[1]="$(awk '/int_addr[1]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[2]="$(awk '/int_addr[2]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[3]="$(awk '/int_addr[3]/{print $NF}' $HOME/reboot_helper.txt)"
	server_allowed_ips[0]="$(awk '/server_allowed_ips[0]/{print $NF}' $HOME/reboot_helper.txt)"
	server_allowed_ips[1]="$(awk '/server_allowed_ips[1]/{print $NF}' $HOME/reboot_helper.txt)"
	client_allowed_ips[0]="$(awk '/client_allowed_ips[0]/{print $NF}' $HOME/reboot_helper.txt)"
	client_allowed_ips[1]="$(awk '/client_allowed_ips[1]/{print $NF}' $HOME/reboot_helper.txt)"
	dns_addr[0]="$(awk '/dns_addr[0]/{print $NF}' $HOME/reboot_helper.txt)"
	dns_addr[1]="$(awk '/dns_addr[1]/{print $NF}' $HOME/reboot_helper.txt)"
	save_conf="$(awk '/save_conf/{print $NF}' $HOME/reboot_helper.txt)"
	listen_port="$(awk '/listen_port/{print $NF}' $HOME/reboot_helper.txt)"=
	ipv6_choice="$(awk '/ipv6_choice/{print $NF}' $HOME/reboot_helper.txt)"
	keychoice="$(awk '/keychoice/{print $NF}' $HOME/reboot_helper.txt)"
	e_choice="$(awk '/e_choice/{print $NF}' $HOME/reboot_helper.txt)"
	pka_choice="$(awk '/pka_choice/{print $NF}' $HOME/reboot_helper.txt)"
	pka_num="$(awk '/pka_num/{print $NF}' $HOME/reboot_helper.txt)"
	client_name="$(awk '/client_name/{print $NF}' $HOME/reboot_helper.txt)"
	wg_intrfc="$(awk '/wg_intrfc/{print $NF}' $HOME/reboot_helper.txt)"
	pi_intrfc="$(awk '/pi_intrfc/{print $NF}' $HOME/reboot_helper.txt)"
	mobile_choice="$(awk '/mobile_choice/{print $NF}' $HOME/reboot_helper.txt)"
	auto_start_choice="$(awk '/auto_start_choice/{print $NF}' $HOME/reboot_helper.txt)"
fi

# Temporarily change permissions to create keys (/etc/wireguard will be changed to 700 once the script finishes)
if [[ ! -d /etc/wireguard ]]; then
	sudo mkdir /etc/wireguard 
fi
sudo chmod 077 /etc/wireguard
cd /etc/wireguard
umask 077

# Create the preshared key if the user chose that option
if [[ "${keychoice^^}" == "Y" ]]; then
        wg genpsk > preshared
elif [[ "${keychoice^^}" == "N" ]]; then
        echo "Okay, moving on then..."
else
        echo "$error_msg"
        exit 1
fi

echo $divider_line

# generate server and client1 private/public keys
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
fi

# Configure post up and post down rules
if [[ "${table_choice^^}" == "Y" ]]; then
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
		post_up_tables="iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $pi_intrfc -j MASQUERADE; ip6tables -A FORWARD -i %i -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $pi_intrfc -j MASQUERADE"
		post_down_tables="iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $pi_intrfc -j MASQUERADE; ip6tables -D FORWARD -i %i -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $pi_intrfc -j MASQUERADE"
	else
		post_up_tables="iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $pi_intrfc -j MASQUERADE"
		post_down_tables="iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $pi_intrfc -j MASQUERADE"
	fi
fi

echo "$divider_line
Okay, I'm now going to create your server and client config files!
They will be located in /etc/wireguard - you will need to use \"sudo\" to open them in the future.
"
sleep 3

# TODO: allow for multiple clients to be added
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

# Check if user wanted to use endpoint on their client config
if [ "$e_choice" == "true" ]; then
	sudo sh -c "echo \"Endpoint = $endp_ip:$listen_port\" >> /etc/wireguard/$client_name.conf"
fi

# Check if user wanted to use preshared keys in the client config
if [[ "${keychoice^^}" == "Y" ]]; then
	sudo sh -c "echo \"PresharedKey = $pre_key\" >> /etc/wireguard/$client_name.conf"
	sudo sh -c "echo \"PresharedKey = $pre_key\" >> /etc/wireguard/$wg_intrfc.conf"
fi

# Check if user wanted to use persistent-keepalive
if [[ "${pka_choice^^}" == "Y" ]]; then
	sudo sh -c "echo 'PersistentKeepalive = $pka_num' >> /etc/wireguard/$client_name.conf"
fi

echo "$divider_line
Okay, I've created the config files for your server and first client!
"

sleep 3

echo $divider_line

echo -e $t_bold"We're done setting up WireGuard on the server-side, so lets start it up!
(I'll pause for a few seconds in case you want to read the output from starting the server)
"$t_reset

# Start the server!
sudo wg-quick up $wg_intrfc
sudo wg
# Sleep for a few seconds to read output
sleep 5

echo $divider_line

if [[ "${mobile_choice^^}" == "Y" ]]; then
	sudo apt install qrencode -y
	sudo sh -c "qrencode -t ansiutf8 < /etc/wireguard/$client_name.conf"
fi

sudo sysctl --system

if [[ "${auto_start_choice^^}" == "Y" ]]; then
	sudo sh -c "systemctl enable wg-quick@$wg_intrfc"
	sudo sh -c "systemctl start wg-quick@$wg_intrfc"
fi

# Restore permissions
cd $DIR
sudo chown -R root:root /etc/wireguard/$wg_intrfc.conf
sudo chmod -R og-rwx /etc/wireguard/$wg_intrfc.conf
sudo chmod 700 /etc/wireguard

# Leave configure_wireguard and create checkpoint.
echo "" > $DIR/wg_config_checkpoint.txt

