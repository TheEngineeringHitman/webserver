#!/bin/bash
clear
echo "################################################"
echo "## Script: setup_wordpress.sh"
echo "## By: Andrew Herren"
echo "## Date: 11/15/2014"
echo "## Script instructions: http//www.theengineeringhitman.com/easy-raspberry-pi-wordpress-install/
echo "## This script is based on a tutorial by Ste W which can be found at:"
echo "## www.raspipress.com/2014/06/tutorial-install-wordpress-on-a-raspberry-pi-using-nginx/"
echo "################################################"

##########variables and settings###########
shopt -s nocasematch
install_time=3
start_install="true"
wp=wordpress-4.1.tar.gz
###########################################

##########questiosn before we start##################
echo -e "\nThis script will install wordpress. If you have any important files or configuration on this SD"
echo "card, you should exit now and make a backup in case anything goes wrong during the install."
echo "Would you like to continue? (y/n) >"
read answer
case "$answer" in
y|yes )
	if [[ "$(whoami)" = "root" ]]; then
		echo "Would you like to update the sources list before continuing? (y/n)>"
		read sources
		echo "Would you like to perform a dist-upgrade before continuing? (y/n)>"
		read upgr
		echo "Would you like to perform autoremove to get rid of old/unused packages before continuing? (y/n)>"
		read autor
		echo "Wordpress will need a mysql username and password to connect to the database."
		echo "In order to create the new user, please first enter the root password you entered"
		echo "when setting up MySQL. >"
		read mysqlroot
		echo "What would you like the username to be? (eg. wpusr)>"
		read wpuser
		echo "What would you like the password to be? >"
		read wppass
		if [[ ! -e /etc/nginx/nginx.conf ]]; then
			echo "Couldn't find Nginx install. If you are sure that you have a webserver installed already"
			echo "then it's safe to continue. However if you do not yet have a webserver, you should"
			echo "install one now. Would you like to execute the setup_webserver.sh script now to install"
			echo "Nginx, PHP, and MySQL now? >"
			read nginx
			case "$nginx" in
			y|yes )
				echo "Webserver script will be executed now..."
				./setup_webserver.sh
				clear
				echo "Webserver scrit done. Contiuing with wordpress install..."
				;;
			esac
		fi
		echo "What is the full path you would like to install wordpress to? For example, if you chose"
		echo "/var/www as your public html directory when installing your webserver, entering that directory"
		echo "here would put your wordpress page at www.yoursite.com. Choosing /var/www/blog instead would"
		echo "put your wordpress page at www.yoursite.com/blog. What directory would you like to use? >"
		read wordpress_dir
#################################################################

###############validating answers###############################
		if [[ "$wpuser" = "" ]]; then
			echo "Error, wordpress database username cannot be blank. Exiting without changes."
			start_install="false"
		fi
		if [[ "$wppass" = "" ]]; then
			echo "Error, wordpress database password cannot be blank. Exiting without changes."
			start_install="false"
		fi
#################################################################

#############software install/setup##############################
		if [[ "$start_install" = "true" ]]; then
			echo "Starting wordpress install. This process normally takes about "$install_time" to complete but can vary"
	                echo "depending on connection speed and options chosen. No more input will be required until the process"
	                echo "has completed so you might want to go do something else for a bit. Press enter"
	                echo "to continue."
	                read garbage
			if [[ ! -d $wordpress_dir ]]; then
				mkdir -p $wordpress_dir
			fi
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
			cur_dir=$(pwd)
			if [[ ! -e "$wp" ]]; then
				wget http://wordpress.org/$wp
			fi
			mv $wp $wordpress_dir
			cd $wordpress_dir
			tar xzvf $wp
			rm $wp
			cp -R wordpress/* .
			rm -r wordpress/
			apt-get -q -y install php5-curl php5-gd libssh2-php php-apc
			mysql -uroot -p$mysqlroot -e "CREATE DATABASE wpress_db"
			mysql -uroot -p$mysqlroot -e "CREATE USER '$wpuser'@'localhost' IDENTIFIED BY '$wppass';"
			mysql -uroot -p$mysqlroot -e "GRANT ALL PRIVILEGES ON wpress_db.* TO '$wpuser'@'localhost';"
			mysql -uroot -p$mysqlroot -e "FLUSH PRIVILEGES;"
			awk -v dbuser="$wpuser" -v dbpass="$wppass" '{
			if($0~/DB_NAME/) 
				print "define(\"DB_NAME\", \"wpress_db\");";
			else if ($0~/DB_USER/)
				print "define(\"DB_USER\", \""dbuser"\");";
			else if ($0~/DB_PASSWORD/)
				print "define(\"DB_PASSWORD\", \""dbpass"\");";
			else if ($0~/DB_COLLATE/)
				print $0"\n\ndefine(\"FS_METHOD\", \"direct\");";
			else
				print $0;
			}' wp-config-sample.php > wp-config.php
			chown -R www-data:www-data $wordpress_dir
			chmod -R 750 $wordpress_dir
			chmod 644 $wordpress_dir/wp-config.php
			chmod -R 755 $wordpress_dir/wp-content/
			cd $cur_dir
			echo "Wordpress has now been installed. If all went well, you should be able to point"
			echo "your web browser to your site and complete the setup of your wordpress site."
		fi
	else
		echo "This script must be run as root. Please try again using sudo."
	fi
	;;
* )
	echo "Exiting without changes."
	;;
esac
shopt -u nocasematch
