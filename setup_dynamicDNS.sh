#!/bin/bash
clear
echo "################################################"
echo "## Script: setup_dynamicDNS.sh"
echo "## By: Andrew Herren"
echo "## Date: 11/07/14"
echo "## Script instructions: http://www.theengineeringhitman.com/http://www.theengineeringhitman.com/"
echo "## This script is based on a tutorial which can be found at:"
echo "## www.techjawab.com/2013/06/setup-dynamic-dns-dyndns-for-free-on.html"
echo "################################################"

shopt -s nocasematch
echo -e "\nThis script will help you install and configure inadyn to work with freedns.afraid.org."
echo "You should setup your account with freedns.affraid.org before continuing."
echo "Proceed with installation? (y/n)>"
read answer
case "$answer" in 
y|yes )
	if [[ $(whoami) = "root" ]]; then
		echo "Would you like to update the sources list before continuing? (y/n)>"
		read sources
		echo "Would you like to perform a dist-upgrade before continuing? (y/n)>"
		read upgr
		echo "Would you like to perform autoremove to get rid of old/unused packages before continuing? (y/n)>"
		read autor
		case "$sources" in
		y|yes )
			echo "Performing update to sources list..."
			apt-get -q -y update
			;;
		* )
			echo "Skipping update to sources list..."
			;;
		esac
		case "$upgr" in
		y|yes)
			echo "Performing dist-upgrade..."
			apt-get -q -y dist-upgrade
			;;
		* )
			echo "Skipping dist-upgrade..."
			;;
		esac
		case "$autor" in
		y|yes )
			echo "Performing autoremove..."
			apt-get -q -y autoremove
			;;
		* )
			echo "Skipping autremove..."
			;;
		esac
		echo "Please enter your freedns username. >"
		read username
		echo "Please enter your freedns password. >"
		read password
		echo "Please enter your domain name. >"
		read domain
		echo "Please enter the freedns key associated with this domain. >"
		read key
		echo "Would you like me to automatically update the server names in your"
		echo "/etc/nginx/sites-available/default file? You should probably only do"
		echo "this if you used my script to setup your webserver. (y/n) >"
		read servername
		echo "Begning installation..."
		apt-get -q -y install inadyn
		echo "Installation complete. Writing conf file."
		echo "--username "$username > /etc/inadyn.conf
		echo "--password "$password >> /etc/inadyn.conf
		echo "--update_period 3600" >> /etc/inadyn.conf
		echo "--forced_update_period 14400" >> /etc/inadyn.conf
		echo "--alias "$domain","$key >> /etc/inadyn.conf
		echo "--background" >> /etc/inadyn.conf
		echo "--dyndns_system default@freedns.afraid.org" >> /etc/inadyn.conf
		echo "--syslog" >> /etc/inadyn.conf
		echo "/etc/inadyn.conf file created."
		case "$servername" in
		y|yes )
			mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.old
			awk -v name="$name" '//{if($1~/server_name/){print "/tserver_name "name";";}else{print $0}}' /etc/nginx/sites-available/default.old > /etc/nginx/sites-available/default
			;;
		* )
			echo "Don't forget to update the server name in your webserver config file"
			;;
		esac
		echo "Updating crontab..."
		crontab -l > dyndns_crontab
		echo "@reboot /usr/sbin/inadyn" >> dyndns_crontab
		crontab dyndns_crontab
		rm dyndns_crontab
		echo "Starting inadyn..."
		inadyn
		echo "done."
	else
		echo "This option must be run as root. Please try again with sudo."
	fi
	;;
* )
	echo "Exiting without changes."
	;;
esac
shopt -u nocasematch

