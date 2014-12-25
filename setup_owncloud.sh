#!/bin/bash
clear
echo "################################################"
echo "## Script: setup_owncloud.sh"
echo "## By: Andrew Herren"
echo "## Date: 11/07/14"
echo "## This script is based on a tutorial that can be found at:"
echo "## www.techjawab.com/2014/08/how-to-setup-owncloud-7-on-raspberry-pi.html"
echo "################################################"

owncloud="owncloud-7.0.4.tar.bz2"

shopt -s nocasematch
echo -e "\nThis script will help setup and configure "$owncloud". Would you like to continue? (y/n)>"
read answer
ok_to_continue="false"
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
		if [[ ! -e "$owncloud" ]]; then
			wget https://download.owncloud.org/community/$owncloud
		fi
		if [[ -e /etc/nginx/sites-available/default && -e /etc/php5/fpm/php.ini ]]; then
			echo "Nginx and php5 found..."
			ok_to_continue="true"
		else
			echo "Owncloud requiers a webserver and php. I haven't found an Nginx install in the default"
			echo "location. This could mean you havent installed one yet or it might be that you installed"
			echo "one using a method other than one of my scripts. If you are sure you have a setup web"
			echo "web server, press n, otherwise press y to run my setup_webserver.sh script now. y/n>"
			read input
			case "$input" in
			y|yes )
				echo "Startin setup_webserver.sh script now..."
				./setup_webserver.sh
				clear
				echo "setup_webserver.sh script finished. Continuing with owncloud install..."
				ok_to_continue="true" 
				;; 
			n|no )
				echo "Because you are running a webserver that this script cannot configure, you may"
				echo "need to do some additional work to configure .htaccess and other security"
				echo "features. Please visit owncloud.org for additional details. Press enter to continue."
				read junk
				ok_to_continue="true"
				do_www_conf="false"
				;;
			esac
		fi
		if [[ "$ok_to_continue" = "true" ]]; then
			echo "Enter the name of the directory that you would like owncloud installed to. "
			echo "This must be a directory that is made available via your webserver. For example"
			echo "if your public html directory is  /var/www/ and you entered /var/www here, then"
			echo "Owncloud would be accessable at www.yoursite.com. If instead you entered /var/www/cloud"
			echo "here, then owncloud would be accessable at www.yoursite.com/cloud >"
			read dir
			if [[ ! -d $dir ]]; then
				echo "Creating directory."
				mkdir -p $dir
			fi
			if [[ ! do_www_conf == "false" ]]; then
				echo "Would you like to automatically configure the requried owncloud security settings?"
				echo "You should only do this if your webserver was installed using one of my scripts"
				echo "and you have not made changes to /etc/nginx/sites-avaialble/default. Continue"
				echo "with security changes? (y/n) >"
				read changes
				case "$changes" in
				y|yes )
					do_www_conf="true"
					echo "Would you like to enforce SSL for owncloud? This means that when you go"
					echo "to "$dir" via http, it will automatcially redirect you to https. You should"
					echo "Only do this if you have setup SSL on your site. Enforce https? (y/n) >"
					read enforce
					case "$enforce" in 
					y|yes )
						enforce_https="true"
						;;
					* )
						enforce_https="false"
						;;
					esac
					;;
				* )
					do_www_conf="false"
					;;
				esac
			fi
			echo "Owncloud will require a new user account on your MySQL database. Please enter"
			echo "The root password of your MySQL installation so that I can create the new user. >"
			read mysqlroot
			echo "Please enter the MySQL username that you would like to create for Owncloud (eg. CloudUser). >"
			read clouduser
			echo "Please enter the MySQL password to create for "$clouduser". >"
			read cloudpass
			if [[ "$ok_to_continue" = "true" ]]; then
				mv /etc/php5/fpm/php.ini /etc/php5/fpm/php.ini.old
				awk '//{
					if($0~/upload_max_filesize/){
						print "upload_max_filesize = 1000M";
					}else if($0~/post_max_size/){
						print "post_max_size = 1000M";
					}}' /etc/php5/fpm/php.ini.old > /etc/php5/fpm/php.ini
				/etc/init.d/php5-fpm restart
				mysql -uroot -p$mysqlroot -e "CREATE DATABASE owncloud_db"
				mysql -uroot -p$mysqlroot -e "CREATE USER '$clouduser'@'localhost' IDENTIFIED BY '$cloudpass';"
				mysql -uroot -p$mysqlroot -e "CREATE USER '$clouduser'@'localhost' IDENTIFIED BY '$cloudpass';"
				mysql -uroot -p$mysqlroot -e "FLUSH PRIVILEGES;"
				curr_dir=$pwd
				mv $owncloud $dir
				cd $dir
				tar -xvf $owncloud
				rm $owncloud
				mv owncloud/* .
				mv owncloud/.htaccess .
				rmdir owncloud
				echo "<?PHP" > config/autoconfig.php
				echo "  \$AUTOCONFIG = array(" >> config/autoconfig.php
				echo "    \"dbtype\"        => \"mysql\"," >> config/autoconfig.php
				echo "    \"dbname\"        => \"$owncloud_db\"," >> config/autoconfig.php
				echo "    \"dbuser\"        => \"$clouduser\"," >> config/autoconfig.php
				echo "    \"dbpass\"        => \"$cloudpass\"," >> config/autoconfig.php
				echo "    \"dbhost\"        => \"localhost\"," >> config/autoconfig.php
				echo "    \"directory\"     => \"$dir\"," >> config/autoconfig.php
				echo "  );" >> config/autoconfig.php
				echo "?>" >> config/autoconfig.php
				if [[ -e "/etc/nginx/sites-available/default" && $do_www_conf == "true" ]]; then
					mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.old
					wwwroot=$(awk 'begin{x=0}/root/{if($1~/root/&&x==0){
						print substr($2,0,length($2));
						x=1;
						}}' /etc/nginx/sites-available/default.old)
					wwwdir=${dir#$wwwroot}
					if [[ ! $wwwdir =~ /$ ]]; then
						wwwdir=$wwwdir/
					fi
					if [[ $wwwdir =~ ^/ ]]; then
						wwwdir=${wwwdir,1}
					fi
					if [[ $enforce_https == "true" ]]; then
						awk -v wwwdir="$wwwdir" 'begin{x=0}//{
							if($0~/error_page 404/ && x==0){
								print $0"\n\n\t location ~/"wwwdir" {\n\t\treturn 301 https://\$server_name\$request_uri;\n\t}";
								x=1;
							}else if($0~/error_page 404/){
								print $0"\n\n\tlocation ~/"wwwdir"(?:\.htaccess|data|config|db_structure\.xml|README) {\n\t\tdeny all;\n\t}";
							}else{
								print $0;
							}
						}' /etc/nginx/sites-available/default.old > /etc/nginx/sites-available/default
					else
						awk -v wwwdir="$wwwdir" '//{
							if($0~/error_page 404/){
								print $0"\n\n\tlocation ~/"wwwdir"(?:\.htaccess|data|config|db_structure\.xml|README) {\n\t\tdeny all;\n\t}";
							}else{
								print $0;
							}
						}' /etc/nginx/sites-available/default.old > /etc/nginx/sites-available/default
					fi
				fi
				cd $curr_dir
				chown -R www-data:www-data $dir
				chmod -R 750 $dir
				/etc/init.d/nginx restart
				echo "Owncloud installation complete. Please visit your website to login."
			fi
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
