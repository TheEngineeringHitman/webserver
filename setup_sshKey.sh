#!/bin/bash
clear
echo "#########################################################"
echo "## By: Andrew Herren"
echo "## Date: 11/13/2014"
echo "## Script Instructions: http://www.theengineeringhitman.com/securing-raspberry-pi-ssh/"
echo "## This script helps setup private key ssh access. It is based on a tutorial found at:"
echo "## https://www.linode.com/docs/security/securing-your-server"
echo "###########################################################"

shopt -s nocasematch
echo -e "\nThis script will configure your pi to only allow ssh access from machines an associated private key."
echo "Would you like to continue? (y/n)>"
read answer
case "$answer" in
y|yes )
	if [[ "$(whoami)" = "root" ]]; then
		echo "Warning, once this script has been run, you will not be able to login to this machine via ssh except"
		echo "from machines which have the private key associated with the public key in ~/.ssh/authorized_keys."
		echo "If this file does not yet exist for the ssh user and/or the public key has not yet been put in the"
		echo "file, exit this script now and make those changes first!"
		echo "Would you like to proceed with disabling root ssh access and password based ssh access? (y/n)>"
		read answer
		case "$answer" in
		y|yes )
			echo "Enter username that has ssh access. >"
			read user
			if [[ ! -e /home/$user/.ssh/authorized_keys ]]; then
				echo "WARNING! No authorized_keys file found for this user! This user will not have ssh access if you proceed."
				echo "Continue with dissabling root ssh access and password based ssh access? (y/n)>"
				read changes_ok
			else
				changes_ok="y"
			fi
			case "$changes_ok" in
			y|yes )
				cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
				awk '{
				if($0~/PasswordAuthentication /) 
					print "PasswordAuthentication no";
				else if($0~/PermitRootLogin/&&$0!~/without/)
					print "PermitRootLogin no";
				else
					print $0;
				}' /etc/ssh/sshd_config.bak > /etc/ssh/ssh2_config
				service ssh restart
				;;
			* )
				echo "Exiting without changes."
				;;
			esac
			;;
		* )
			echo "Exiting without changes."	
			;;
		esac
	else
		echo "This script must be run as root. Please try again using sudo"
	fi
	;;
*)
	echo "Exiting without changes."
	;;
esac
shopt -u nocasematch
