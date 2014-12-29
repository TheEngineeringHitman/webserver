#!/bin/bash
clear
echo "################################################"
echo "## Script: setup_piWatchdog.sh"
echo "## By: Andrew Herren"
echo "## Date: 11/14/2014"
echo "## Script instructions: http://www.theengineeringhitman.com/setting-raspberry-pi-watchdog-timer/"
echo "## This script is based on a tutorial bye Philip Howard which can be found at:"
echo "## pi.gadgetoid.com/article/who-watches-the-watcher"
echo "################################################"

shopt -s nocasematch
echo -e "\nThis script will configure the pi's onboard watchdog timer such that if it hangs, pi will"
echo "automatically reboot itself. Would you like to continue? (y/n) >"
read answer
case "$answer" in
y|yes )
	if [[ "$(whoami)" = "root" ]]; then
		echo "It is recommended to always have an updated sources list. Update sources now? (y/n)>"
		read upsources
		echo "It is recommended to always run the latest version of Raspbian. Preform dist-upgrade now? (y/n)>"
		read upgrade
		echo "It is recommended to run autoremove to remove old and unused modules. Run autoremove now? (y/n)>"
		read autor
		case "$upsources" in
		y|Y )
			echo "Updating sources..."
			apt-get -q -y update
			;;
		n|N )
			echo "Skipping update of sources..."
			;;
		* )
			echo "Unrecognized answer for sources update. Skipping update."
			;;
		esac
		case "$upgrade" in
		y|Y )
	                echo "Updating distribution..."
	                apt-get -q -y dist_upgrade
	                ;;
	        n|N )
	                echo "Skipping update of distrubution..."
	                ;;
	        * )
	                echo "Unrecognized answer for distribution upgrade. Skipping upgrade."
	                ;;
		esac
		case "$autor" in
	        y|Y )
	                echo "Preforming autoremove..."
	                apt-get -q -y autoremove
	                ;;
	        n|N )
	                echo "Skipping autoremove..."
	                ;;
	        * )
	                echo "Unrecognized answer for autoremove. Skipping autoremove."
	                ;;
		esac
		modprobe bcm2708_wdog
		apt-get -q -y install watchdog 
		update-rc.d watchdog defaults
		mv /etc/default/watchdog /etc/default/watchdog.old
		awk '{
		if($0~/watchdog_module/)
			print "watchdog_module = \"bcm2708_wdog\"";
		else
			print $0
		}' /etc/default/watchdog.old > /etc/default/watchdog
		mv /etc/watchdog.conf /etc/watchdog.conf.old
		awk '{
		if($0~/#watchdog-device/)
			print "watchdog-device\t\t= /dev/watchdog";
		else if($0~/max-load-1/)
			print "max-load-1\t\t= 24"; 
		else 
		print $0}' /etc/watchdog.conf.old > /etc/watchdog.conf
		/etc/init.d/watchdog start
		echo "Watchdog has been configured."
	else
		echo "This script must be run as root. Please try again using sudo."
	fi
	;;
* )
	echo "Exiting without changes."
	;;
esac
shopt -u nocasematch
