
if [[ -f $HOME/reboot_helper.txt ]]; then
	int_addr[0]="$(awk '/int_addr[0]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[1]="$(awk '/int_addr[1]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[2]="$(awk '/int_addr[2]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[3]="$(awk '/int_addr[3]/{print $NF}' $HOME/reboot_helper.txt)"
	wg_intrfc="$(awk '/wg_intrfc/{print $NF}' $HOME/reboot_helper.txt)"
	ipv6_choice="(awk '/ipv6_choice/{print $NF}' $HOME/reboot_helper.txt)"

	pi_intrfc="$(awk '/pi_intrfc/{print $NF}' $HOME/reboot_helper.txt)"
	listen_port="$(awk '/listen_port/{print $NF}' $HOME/reboot_helper.txt)"
	modded_ip="$(awk '/modded_ip/{print $NF}' $HOME/reboot_helper.txt)"
	pka_choice="$(awk '/pka_choice/{print $NF}' $HOME/reboot_helper.txt)"
	table_choice="(awk '/table_choice/{print $NF}' $HOME/reboot_helper.txt)"
fi

# Install pi-hole
install_pihole(){
	echo "Alright, let's start setting up pi-hole. First I'm going to install resolvconf, and then
I'll explain your next steps! $divider_line"
	sleep 2
	# Install resolvconf before pi-hole
	sudo apt install resolvconf -y

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
	if [[ "${p_start_choice^^}" == "Y" ]]; then
# echo '
				 # __
		 # _(\    |@@|
		# (__/\__ \--/ __         See You Soon!
		   # \___|----|  |   __
			   # \ }{ /\ )_ / _\
			   # /\__/\ \__O (__
			  # (--/\--)    \__/
			  # _)(  )(_
			 # `---  ---`

# '
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
	sudo cat <<EOF> /etc/unbound/unbound.conf.d/pi-hole.conf
server:
	# If no logfile is specified, syslog is used
	# logfile: "/var/log/unbound/unbound.log"
	verbosity: 0

	port: 5353
	do-ip4: yes
	do-udp: yes
	do-tcp: yes

	# May be set to yes if you have IPv6 connectivity
	do-ip6: $unb_ipv6

	# Use this only when you downloaded the list of primary root servers!
	root-hints: "/var/lib/unbound/root.hints"

	# Respond to DNS requests on all interfaces
	#interface: 0.0.0.0
	#max-udp-size: 3072

	# IPs authorised to access the DNS Server
	#access-control: 0.0.0.0/0                 refuse
	#access-control: 127.0.0.1                 allow
	#access-control: $modded_ip.0/24             allow

	# Hide DNS Server info
	#hide-identity: yes
	#hide-version: yes

	# Trust glue only if it is within the servers authority
	harden-glue: yes

	# Require DNSSEC data for trust-anchored zones, if such data is absent, the zone becomes BOGUS
	harden-dnssec-stripped: yes
	#harden-referral-path: yes

	# Add an unwanted reply threshold to clean the cache and avoid, when possible, DNS poisoning
	#unwanted-reply-threshold: 10000000

	# Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
	# see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
	use-caps-for-id: no

	# Reduce EDNS reassembly buffer size.
	# Suggested by the unbound man page to reduce fragmentation reassembly problems
	edns-buffer-size: 1472

	# TTL bounds for cache
	#cache-min-ttl: 3600
	#cache-max-ttl: 86400

	# Perform prefetching of close to expired message cache entries
	# This only applies to domains that have been frequently queried
	prefetch: yes
	#prefetch-key: yes

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


# Check if we are installing pihole or unbound
if [[ $1 == "pihole" ]]; then
	install_pihole
elif [[ $1 == "unbound" ]]; then
	install_unbound
else
	echo $errormsg
	exit 1
fi