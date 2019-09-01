# Easy As Pi Installer
A one-stop-shop to set up WireGuard, Pi-Hole and Unbound for all versions of Raspberry Pi (armhf included!)

## Here's what you need to do first:
1. IMPORTANT: Temporarily set up 'autologin' using the raspi-config utility (you can change this back immediately afterwards)
```sudo raspi-config
In the GUI, navigate to the following setting and enable autologin:
--> 'Boot Options' --> 'B1: Desktop / CLI' --> 'B2 Console Autologin' --> 'OK' --> Close raspi-config
```
2. As mentioned in the script, several commands require the use of 'sudo', so you can choose to run the
script after typing 'sudo su' or let the script manually run the commands for you. Note that if you use a password, 
it will require you to enter it during the steps that require elevated permission. 
The script will ask if you want to run 'sudo --validate' to temporarily disable (for 15 minutes) the need for a password.
3. Install git so you can clone this repo

`sudo apt-get install git -y`

4. Clone this repo and move into the newly made directory
```
cd $HOME && git clone https://github.com/ShaneCaler/EasyAsPiInstaller.git && cd EasyAsPiInstaller
```
5. Run the installer! Type the following below and just follow all of the prompts.
There will be a lot, but that's just because I wanted to offer the ability to customize your setup.
If you have any issues, refer back to here in the troubleshooting section or open up an issue and I'll
try to help out!

`./EasyAsPiInstaller.sh`

## Resources/References:

<details>
           <summary>WireGuard Specific</summary>
			<p>Adrian Mihalko @ https://github.com/adrianmihalko/raspberrypiwireguard</p>
			<p>Angristan @ https://github.com/angristan/wireguard-install/blob/master/wireguard-install.sh</p>
			<p>Angristan @ https://angristan.xyz/how-to-setup-vpn-server-wireguard-nat-ipv6/</p>
			<p>Arch Linux @ https://wiki.archlinux.org/index.php/WireGuard</p>
			<p>Emanuel Duss @ https://emanuelduss.ch/2018/09/wireguard-vpn-road-warrior-setup/</p>
			<p>Official WireGuard docs @ https://www.wireguard.com/quickstart/</p>
</details>

---

<details>
			<summary>WireGuard & Pi-hole (& some Unbound)</summary>
			<p>Aveek Dasmalakar @ https://medium.com/@aveek/setting-up-pihole-wireguard-vpn-server-and-client-ubuntu-server-fc88f3f38a0a</p>
			<p>Daluf @ https://github.com/pirate/wireguard-docs/blob/master/README.md#config-reference</p>
			<p>Harry Pnyce @ https://github.com/harrypnyce/raspbian10-buster/blob/master/README.md</p>
			<p>i4ApvDqgDV @ https://gist.github.com/i4ApvDqgDV/e2e566385cae3081cc9850bdd3ab166f</p>
			<p>Official Pi-hole docs @ https://docs.pi-hole.net/guides/unbound/<p>
			<p>Pi-hole Discourse @ https://discourse.pi-hole.net/t/how-do-i-configure-my-devices-to-use-pi-hole-as-their-dns-server/245</p>
			<p>u/vaporisharc92 @ https://www.reddit.com/r/pihole/comments/bnihyz/guide_how_to_install_wireguard_on_a_raspberry_pi/</p>
</details>

---

<details>
			<summary>Transitioning from iptables to nftables</summary>
			<p>Stamus Networks @ https://home.regit.org/netfilter-en/nftables-quick-howto/<p>
			<p>Official nftalbes docs @ https://wiki.nftables.org/wiki-nftables/index.php/Moving_from_iptables_to_nftables</p>
			<p>Official nftable docs @ https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes</p>
			<p>Gentoo Linux authors @ https://wiki.gentoo.org/wiki/Nftables/Examples#Typical_workstation_.28separate_IPv4_and_IPv6.29</p>
			<p>TLDP authors @ http://www.tldp.org/HOWTO/Linux+IPv6-HOWTO/ch18s05.html</p>
</details>

---

<details>
			<summary>Bash Commands</summary>
			<details> 
						<summary>Methods of running a script on boot</summary>
						<p>- Raspberry Pi Forums @ https://www.raspberrypi.org/forums/viewtopic.php?t=202561 </p>
						<p>- StackExchange question @ https://unix.stackexchange.com/questions/145294/how-to-continue-a-script-after-it-reboots-the-machine</p>
						<p>- Ubuntu Forums @ https://ubuntuforums.org/showthread.php?t=1325843 </p>
			</details>
			<details> 
						<summary>Methods of setting the current working directory</summary>
						<p>- StackOverflow question @ https://stackoverflow.com/questions/3349105/how-to-set-current-working-directory-to-the-directory-of-the-script</p>
						<p>- StackOverflow question @ https://stackoverflow.com/questions/192292/how-best-to-include-other-scripts/12694189#12694189</p>
						<p>- StackOverflow question @ https://stackoverflow.com/questions/59895/get-the-source-directory-of-a-bash-script-from-within-the-script-itself</p>
			</details>
			<details> 
						<summary>Methods of extracting networking/system information</summary>
						<p>- StackOverflow question @ https://stackoverflow.com/questions/21336126/linux-bash-script-to-extract-ip-address</p>
						<p>- StackExchange question @ https://unix.stackexchange.com/questions/412516/create-an-array-with-all-network-interfaces-in-bash</p>
						<p>- AskUbuntu question @ https://askubuntu.com/questions/15853/how-can-a-script-check-if-its-being-run-as-root</p>
						<p>- Raspberry Pi Forums @ https://www.raspberrypi.org/forums/viewtopic.php?t=34678</p>
			</details>
</details>

---

<details>
  <summary>Relevant subreddits</summary>
         <p>https://www.reddit.com/r/pihole/</p>
         <p>https://www.reddit.com/r/wireguard</p>
         <p>https://www.reddit.com/r/raspberry_pi</p>
</details>
