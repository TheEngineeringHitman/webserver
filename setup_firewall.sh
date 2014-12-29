#!/bin/bash
clear
echo "###########################################################"
echo "## Script: setup_firewall.sh"
echo "## By: Andrew Herren"
echo "## Date 11/13/2014"
echo "## Script instructions: http://www.theengineeringhitman.com/setup-raspberry-pi-firewall/"
echo "## This script is based on a tutorial that can be found at:"
echo "## https://www.linode.com/docs/security/securing-your-server"
echo "#############################################################"

shopt -s nocasematch
echo -e "\nThis script will create a basic firewall that only allows access traffic"
echo "To the following services and ports: HTTP (80), HTTPS (443), SSH (22), and ping"
echo "All other ports will be blocked. Changes and additional rules can be made by"
echo "Editing the /etc/iptables.firewall.rules file."
echo "Would you like to continue? (y/n) >"
read answer
case "$answer" in
y|yes )
	if [[ $(whoami) = "root" ]]; then
		rules="/etc/iptables.firewall.rules"
		echo "*filter" > $rules
		echo "" >> $rules
		echo "#  Allow all loopback (lo0) traffic and drop all traffic to 127/8 that doesn't use lo0" >> $rules
		echo "-A INPUT -i lo -j ACCEPT" >> $rules
		echo "-A INPUT -d 127.0.0.0/8 -j REJECT" >> $rules
		echo "" >> $rules
		echo "#  Accept all established inbound connections" >> $rules
		echo "-A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT" >> $rules
		echo "" >> $rules
		echo "#  Allow all outbound traffic - you can modify this to only allow certain traffic" >> $rules
		echo "-A OUTPUT -j ACCEPT" >> $rules
		echo "" >> $rules
		echo "#  Allow HTTP and HTTPS connections from anywhere (the normal ports for websites and SSL)." >> $rules
		echo "-A INPUT -p tcp --dport 80 -j ACCEPT" >> $rules
		echo "-A INPUT -p tcp --dport 443 -j ACCEPT" >> $rules
		echo "" >> $rules
		echo "#  Allow SSH connections" >> $rules
		echo "#" >> $rules
		echo "#  The -dport number should be the same port number you set in sshd_config" >> $rules
		echo "#" >> $rules
		echo "-A INPUT -p tcp -m state --state NEW --dport 22 -j ACCEPT" >> $rules
		echo "" >> $rules
		echo "#  Allow ping" >> $rules
		echo "-A INPUT -p icmp --icmp-type echo-request -j ACCEPT" >> $rules
		echo "" >> $rules
		echo "#  Log iptables denied calls" >> $rules
		echo "-A INPUT -m limit --limit 5/min -j LOG --log-prefix \"iptables denied: \" --log-level 7" >> $rules
		echo "" >> $rules
		echo "#  Drop all other inbound - default deny unless explicitly allowed policy" >> $rules
		echo "-A INPUT -j DROP" >> $rules
		echo "-A FORWARD -j DROP" >> $rules
		echo "" >> $rules
		echo "COMMIT" >> $rules
		echo "Rules created. Applying changes..."
		iptables-restore < /etc/iptables.firewall.rules
		echo "Firewall rules in effect are shown below:"
		iptables -L
		echo "Would you like to automatically enable this firewall at each boot? (y/n) >"
		read answer
		case "$answer" in
		y|yes )
			echo "#!/bin/bash" > /etc/network/if-pre-up.d/firewall
			echo "/sbin/iptables-restore < /etc/iptables.firewall.rules" >> /etc/network/if-pre-up.d/firewall
			chmod +x /etc/network/if-pre-up.d/firewall
			echo "Startup script /etc/network/if-pre-up.d/firewall has been created."
			;;
		* )
			;;
		esac
		echo "Firewall setup finished."
	else
		echo "This script must be run as root. Please try again using sudo."
	fi
	;;
* )
	echo "Exiting without changes..."
	;;
esac
shopt -u nocasematch
