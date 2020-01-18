
if [[ -f $HOME/reboot_helper.txt ]]; then
	DIR="$(awk '/DIR/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[0]="$(awk '/int_addr[0]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[1]="$(awk '/int_addr[1]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[2]="$(awk '/int_addr[2]/{print $NF}' $HOME/reboot_helper.txt)"
	int_addr[3]="$(awk '/int_addr[3]/{print $NF}' $HOME/reboot_helper.txt)"
	ipv6_choice="(awk '/ipv6_choice/{print $NF}' $HOME/reboot_helper.txt)"
	pi_intrfc="$(awk '/pi_intrfc/{print $NF}' $HOME/reboot_helper.txt)"
	modded_ip="$(awk '/modded_ip/{print $NF}' $HOME/reboot_helper.txt)"
fi

pi_prv_ip4=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
pi_prv_ip6=$(ip -6 addr show dev $pi_intrfc | grep 'fe80' | awk '{print $2}')

# Install pi-hole
install_pihole(){
	echo "Alright, let's start setting up pi-hole. First I'm going to install resolvconf, and then
I'll explain your next steps! $divider_line"
	sleep 2
	# Install resolvconf before pi-hole
	sudo apt install resolvconf -y

	echo -e $t_important"---------IMPORTANT!! PLEASE READ!!---------"$t_reset
	echo "You will now be redirected the pi-hole installer. You'll need to go through this process on your own,"
	echo "but for the most part, the default choices are all suitable. I'll take you through the 9 steps now:"
	echo -e "$t_bold"Step 1:"$t_reset Press '<OK>' until you reach the 'Choose An Interface' screen."
	echo "	- eth0 = ethernet and wlan0 = WiFi, choose according to what your device is connected to currently. (Likely ${pi_intrfc})"
	echo -e "$t_bold"Step 2:"$t_reset Set the Upstream DNS Provider to whomever you prefer. If you plan on"
	echo "using Unbound, this setting doesn't matter much, so just choose anything for now."
	echo  -e "$t_bold"Step 3:"$t_reset Select the 'Block Lists' to enable - I suggest enabling them all."
	echo  -e "$t_bold"Step 4:"$t_reset Choose IPv4 or both if you chose to use IPv6 earlier."
	echo  -e "$t_bold"Step 5:"$t_reset Static addresses should be your device's local private address: "
	echo "	- ${pi_prv_ip4}/${int_addr[1]} for IPv4 or ${pi_prv_ip6}/${int_addr[3]} for IPv6."
	echo "	- Gateway is likely your router's IP address. The defaults for these options should reflect this."
	echo  -e "$t_bold"Step 6:"$t_reset I highly recommend installing the web admin interface!"
	echo  -e "$t_bold"Step 7:"$t_reset If you don't already have a webserver installed (most general users won't)"
	echo "Then I recommend installing the web server (lighttpd) as well."
	echo  -e "$t_bold"Step 8:"$t_reset Again, I say go with what pi-hole recommends and turn logging on, unless"
	echo "you have a specific reason not to."
	echo  -e "$t_bold"Step 9:"$t_reset If you want less clutter in your logs you can choose one of these options, "
	echo "But to get the most out of the pi-hole I think it's best to Show Everything."
	echo "And thats it for pi-hole!"
	echo "----------------------------------------------------------------------------------------------------"
	echo "NOTE: This installation method uses the command: # sudo curl -ssL https://instal.pi-hole.net | bash"
    echo "It is generally bad practice to curl into bash, but in this case we know that"
    echo "the script is from a reputable source. It still couldn't hurt to look over the code yourself"
    echo "if you're concered or interested! There are also alternative download methods on the pi-hole website."
	echo -e $t_important"IMPORTANT: YOU MUST MANUALLY REBOOT ONCE PI-HOLE IS FINISHED INSTALLING"$t_reset
	echo -e $t_important"IF AUTOLOGIN IS ENABLED, THIS SCRIPT SHOULD PICK BACK UP WHERE WE LEFT OFF"$t_reset
	echo "I recommend screenshotting these instructions if you are using SSH, "
	echo "Or just take a picture with your phone. Good luck and I'll see you once you're done!"
	read -rp "$(echo -e $t_readin"Enter 'Y' whenever you're ready to start the pi-hole installation ('N' to do it yourself later): "$t_reset)" -e -i "" p_start_choice
	if [[ "${p_start_choice^^}" == "Y" ]]; then
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
		echo "pi-hole checkpoint" > $DIR/pihole_checkpoint.txt
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
	sudo apt install unbound -y

	# Install current root hints file
	sudo wget -O root.hints https://www.internic.net/domain/named.root
	sudo mv root.hints /var/lib/unbound/

	# Determine unbound variable values
	if [[ "${ipv6_choice^^}" == "Y" ]]; then
		unb_ipv6="yes"
	else
		unb_ipv6="no"
	fi
	
	modded_pi_prv_ip4=$(echo "${pi_prv_ip4}" | cut -f -3 -d'.')
	modded_wg_ip4=$(echo "${int_addr[0]}" | cut -f -3 -d'.')
	
	# Configure Unbound - credit to Github user notasausage 
	# for many of the non-default server configurations
	sudo sh -c "cat <<EOF> /etc/unbound/unbound.conf.d/pi-hole.conf
server:
    # If no logfile is specified, syslog is used
    # logfile: "/var/log/unbound/unbound.log"
    verbosity: 1

	# Default port to answer queries from is 53, 
	# but we're going to use 5353. If you change this,
	# make sure to use this port number in your pi-hole
	# admin dashboard, as explained in the Github readme.
    port: 5353
	
    do-ip4: yes
    do-udp: yes
    do-tcp: yes

    # May be set to yes if you have IPv6 connectivity
    do-ip6: $unb_ipv6

    # Use this only when you downloaded the list of primary root servers!
    root-hints: "/var/lib/unbound/root.hints"
	
	# 0.0.0.0@53 and ::0@53 allows the server to 
	# respond to DNS requests on all available interfaces over port 53.
	# Default is to listen to localhost (127.0.0.1 and ::1)
	interface: 0.0.0.0@53
	interface: ::0@53
	
	# Hide DNS Server info, default is no.
	# Server will not answer any id.server, hostname.bind, 
	# version.server, and version.bind queries if both are 'yes'
	hide-identity: yes
	hide-version: yes

    # Trust glue only if it is within the servers authority
    harden-glue: yes

    # Require DNSSEC data for trust-anchored zones, if such data is absent, the zone becomes BOGUS
	harden-dnssec-stripped: yes
	
	# Burdens the authority servers, not RFC standard, and could lead to performance problems
	harden-referral-path: no

	# Harden against algorithm downgrade when multiple algorithms
	# are advertised in the DS record. If no, allows for the weakest
	# algorithm to validate the zone. Default is no.
	harden-algo-downgrade: yes
	
	# Harden against questionably large queries
	harden-large-queries: yes
	
	# Add an unwanted reply threshold to clean the cache and avoid, when possible, DNS poisoning
	# Default is 0, number supplied was suggested in example config.
	unwanted-reply-threshold: 10000000

    # Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
    # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
    use-caps-for-id: no

    # Reduce EDNS reassembly buffer size, default is 4096
    # Suggested by the unbound man page to reduce fragmentation (timeout) problems
    edns-buffer-size: 1472

    # Perform prefetching of close to expired message cache entries
    # This only applies to domains that have been frequently queried
    prefetch: yes
	
	# Fetch the DNSKEYs earlier in the validation process, which lowers the latency of requests
	# but also uses a little more CPU (performs key lookups adjacent to normal lookups)
	# Default is no. 
	prefetch-key: yes
	
	# Time To Live (in seconds) for DNS cache. Set cache-min-ttl to 0 remove caching (default).
	# Max cache default is 86400 (1 day).
	cache-min-ttl: 3600
	cache-max-ttl: 86400
	
	# Use about 2x more for rrset cache, 
	# total memory use is about 2-2.5x total cache size
	# Default is 4m/4m
	msg-cache-size: 8m
	rrset-cache-size: 16m

	# Default is 1 (disabled), which is fine for most machines.
	# You may increase this to create more threads if your device is capable.
    num-threads: 1

    # Ensure kernel buffer is large enough to not lose messages in traffic spikes
    so-rcvbuf: 1m

	# Which client IPs are authorized to make recursive queries to this server.
	# Deny traffic from all sources other than this device,
	# your local private subnet and your WireGuard subnet.
	# Default is refuse everything but localhost (127.0.0.1)
	# See Unbound man page/example config for more information.
	access-control: 0.0.0.0/0 refuse
	access-control: 127.0.0.1 allow
	access-control: $modded_pi_prv_ip4.0/24 allow
	access-control: $modded_wg_ip4.0/24 allow

    # Enforce privacy of local IP ranges - strips them away from answers
	# Note: May cause DNSSEC to additionally mark it bogys.
	# Protects against 'DNS Rebinding', no defaults.
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    private-address: fd00::/8
    private-address: fe80::/10
	
	# Allow the domain, and its subdomains, to contain private addresses. 
	# Create DNS record for Pi-Hole Web Interface
	private-domain: "pi.hole"
	local-zone: "pi.hole" static
	local-data: "pi.hole IN A $modded_pi_prv_ip4.0/24"

EOF

"
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