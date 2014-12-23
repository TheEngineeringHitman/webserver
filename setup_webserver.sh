#!/bin/bash
clear
echo "################################################"
echo "## Script: setup_nginx.sh"
echo "## By: Andrew Herren"
echo "## Date: 11/07/14"
echo "##"
echo "## This script mostly automates two tutorials written by Matt Wilcox which can be found at:"
echo "## https://mattwilcox.net/archives/setting-up-a-recent-version-of-nginx-with-https-and-spdy-support-on-a-raspberry-pi/"
echo "## https://mattwilcox.net/archives/setting-up-a-secure-home-web-server-with-raspberry-pi/ "
echo "################################################"

export VERSION_PCRE=pcre-8.36
export VERSION_OPENSSL=openssl-1.0.1j
export VERSION_NGINX=nginx-1.7.8

install_time=13
compile_time=20

shopt -s nocasematch
nginx_config="/etc/nginx/sites-available/default"

default_ip=$(hostname --all-ip-addresses)

echo -e "\nThis script will help setup an Nginx web server with PHP and MySQL. If you have any important files"
echo "or configuration on this SD card, I would recommend making a backup before continuing in case"
echo "anything goes wrong during the installation. Would you like to continue? (y/n)>"
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
		echo "Enter the IP address or domain name you will use for this web server. This will be used to configure"
		echo "the etc/nginx/sites-available/default file but can be changed later if needed. If you leave this blank"
		echo "I will use your current IP of "$default_ip" >"
		read server_ip
		if [[ $server_ip == "" ]]; then
			server_ip=$default_ip
		fi
		echo "Would you like to use the default packages found with apt-get or would you like to compile from"
                echo "the latest sources? Recompiling is slow (will add 20-30min) but results in the latest code including"
                echo "fixes that will result in a more securing server. Compile from source? (y/n) >"
		read compile
		echo "Would you like to setup SSL for this webserver? This can always be done later as well. (y/n) >"
		read setup_ssl
		echo "Where would you like to place the public html direcotry for your webserver. By default Nginx uses"
		echo "/usr/share/nginx/www however, many people like /var/www. Please type the full path now. >"
		read http_dir
		if [[ $http_dir = "" ]]; then
			http_dir="/usr/share/nginx/www."
		elif [[ $http_dir != $/ ]]; then
			http_dir=$http_dir"/"
		fi
		
		case $compile in
		y|yes )
			install_time=$(($install_time+$compile_time))
			;;
		esac
		echo -e "\nSetup will begin now. Installation will take approximatly "$install_time" minutes."
                echo "This is just an estimate and can vary depending on your internet speed and other factors."
                echo "In about 30 seconds, the screen will turn blue and you will be asked to set the MySQL root"
		echo "password. After that, no additional interaction will be required until the end of the"
                echo "process so feel free to walk around or grab a drink of water while you wait."
                echo "Press enter to continue."
                read garbage
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
		groupadd www-data
		usermod -a -G www-data www-data
		apt-get -y -q install nginx openssl ssl-cert php5-fpm php5-curl php5-gd php5-mcrypt php5-cli php5-mysql php-apc mysql-server
		case "$compile" in
		y|yes )
			sudo apt-get -y -q remove nginx
			##################################################	
			# Begining of Matt Wilcox script to build nginx
			# goto https://mattwilcox.net/archives/setting-up-a-recent-version-of-nginx-with-https-and-spdy-support-on-a-raspberry-pi
			# for more iformation.
			##########################################################
				
			# URLs to the source directories
			export SOURCE_OPENSSL=https://www.openssl.org/source/
			export SOURCE_PCRE=ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/
			export SOURCE_NGINX=http://nginx.org/download/
		
			# clean out any files from previous runs of this script
			rm -rf build
			mkdir build
		
			# ensure that we have the required software to compile our own nginx
			sudo apt-get -y install curl wget build-essential
				
			# grab the source files
			wget -P ./build $SOURCE_PCRE$VERSION_PCRE.tar.gz
			wget -P ./build $SOURCE_OPENSSL$VERSION_OPENSSL.tar.gz --no-check-certificate
			wget -P ./build $SOURCE_NGINX$VERSION_NGINX.tar.gz
			
			# expand the source files
			cd build
			tar xzf $VERSION_NGINX.tar.gz
			tar xzf $VERSION_OPENSSL.tar.gz
			tar xzf $VERSION_PCRE.tar.gz
			cd ../
		
			# set where OpenSSL and nginx will be built
			export BPATH=$(pwd)/build
			export STATICLIBSSL="$BPATH/staticlibssl"
		
			# build static openssl
			cd $BPATH/$VERSION_OPENSSL
			rm -rf "$STATICLIBSSL"
			mkdir "$STATICLIBSSL"
			make clean
			./config --prefix=$STATICLIBSSL no-shared enable-ec_nistp_64_gcc_128 \
			&& make depend \
			&& make \
			&& make install_sw
		
			# rename the existing /etc/nginx directory so it's saved as a back-up
			mv /etc/nginx /etc/nginx-bk
			
			# build nginx, with various modules included/excluded
			cd $BPATH/$VERSION_NGINX
			mkdir -p $BPATH/nginx
			./configure --with-cc-opt="-I $STATICLIBSSL/include -I/usr/include" \
			--with-ld-opt="-L $STATICLIBSSL/lib -Wl,-rpath -lssl -lcrypto -ldl -lz" \
			--sbin-path=/usr/sbin/nginx \
			--conf-path=/etc/nginx/nginx.conf \
			--pid-path=/var/run/nginx.pid \
			--error-log-path=/var/log/nginx/error.log \
			--http-log-path=/var/log/nginx/access.log \
			--with-pcre=$BPATH/$VERSION_PCRE \
			--with-http_ssl_module \
			--with-http_spdy_module \
			--with-file-aio \
			--with-ipv6 \
			--with-http_gzip_static_module \
			--with-http_stub_status_module \
			--without-mail_pop3_module \
			--without-mail_smtp_module \
			--without-mail_imap_module \
			&& make && make install
		
			# rename the compiled /etc/nginx directory so its accessible as a reference to the new nginx defaults
			mv /etc/nginx /etc/nginx-default
		
			# now restore the /etc/nginx-bk to /etc/nginx so the old settings are kept
			mv /etc/nginx-bk /etc/nginx
		
			echo "All done.";
			echo "This build has not edited your existing /etc/nginx directory.";
			echo "If things aren't working now you may need to refer to the";
			echo "configuration files the new nginx ships with as defaults,";
			echo "which are available at /etc/nginx-default";
			###########################################################
			# End Matt Wilcox script
			###########################################################
			rm -rf build
			;;
		* )
			echo "Continuing with precompiled versions..."
		esac
		cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
		nginx_config="/etc/nginx/nginx.conf"
		awk '{
		if($0~/keepalive_timeout/)
			print "#"$0;
		else
			print $0
		}' /etc/nginx/nginx.conf.old > /etc/nginx/nginx.conf.tmp
		awk '
		{
		if($0~/worker_processes/) 
			print "worker_processes 2;";
		else if ($0~/server_tokens/) 
			print "\tserver_tokens off;"; 
		else if ($0~/gzip on/)
			print "\tgzip on;";
		else if ($0~/gzip_min_length/)
			print "\tgzip_min_length\t1100;";
		else if ($0~/gzip_vary/)
			print "\tgzip_vary\ton;";
		else if ($0~/gzip_proxied/)
			print "\tgzip_proxied\tany;";
		else if ($0~/gzip_buffers/)
			print "\tgzip_buffers\t16 8k;";
		else if ($0~/gzip_comp_level/)
			print "\tgzip_comp_level\t6;";
		else if ($0~/gzip_http_version/)
			print "\tgzip_http_version\t1.1;";
		else if ($0~/gzip_types/)
			print "\tgzip_types\ttext/plain text/css application/json application/x-javascript text/xml application/xml application/rss+xml text/javascript images/svg+xml application/x-font-ttf font/opentype application/vnd.ms-fontobject;\n\n\tclient_header_timeout\t10;\n\tclient_body_timeout\t10;\n\tkeepalive_timeout\t10 10;\n\tsend_timeout\t10;"; 
		else
			print $0;
		}' /etc/nginx/nginx.conf.tmp > $nginx_config	
		rm /etc/nginx/nginx/conf.tmp

		fastcgi="/etc/nginx/fastcgi_params"
		cp $fastcgi /etc/nginx/fastcgi_params.old

		echo -e "fastcgi_param\tQUERY_STRING\t\$query_string;" > $fastcgi
		echo -e "fastcgi_param\tREQUEST_METHOD\t\$request_method;" >> $fastcgi
		echo -e "fastcgi_param\tCONTENT_TYPE\t\$content_type;" >> $fastcgi
		echo -e "fastcgi_param\tCONTENT_LENGTH\t\$content_length;" >> $fastcgi
		echo -e "" >> $fastcgi
		echo -e "fastcgi_param\tSCRIPT_FILENAME\t\$document_root\$fastcgi_script_name;" >> $fastcgi
		echo -e "fastcgi_param\tSCRIPT_NAME\t\$fastcgi_script_name;" >> $fastcgi
		echo -e "fastcgi_param\tPATH_INFO\t\$fastcgi_path_info;" >> $fastcgi
		echo -e "fastcgi_param\tREQUEST_URI\t\$request_uri;" >> $fastcgi
		echo -e "fastcgi_param\tDOCUMENT_URI\t\$document_uri;" >> $fastcgi
		echo -e "fastcgi_param\tDOCUMENT_ROOT\t\$document_root;" >> $fastcgi
		echo -e "fastcgi_param\tSERVER_PROTOCOL\t\$server_protocol;" >> $fastcgi
		echo -e "" >> $fastcgi
		echo -e "fastcgi_param\tGATEWAY_INTERFACE\tCGI/1.1;" >> $fastcgi
		echo -e "fastcgi_param\tSERVER_SOFTWARE\tnginx/\$nginx_version;" >> $fastcgi
		echo -e "" >> $fastcgi
		echo -e "fastcgi_param\tREMOTE_ADDR\t\$remote_addr;" >> $fastcgi
		echo -e "fastcgi_param\tREMOTE_PORT\t\$remote_port;" >> $fastcgi
		echo -e "fastcgi_param\tSERVER_ADDR\t\$server_addr;" >> $fastcgi
		echo -e "fastcgi_param\tSERVER_PORT\t\$server_port;" >> $fastcgi
		echo -e "fastcgi_param\tSERVER_NAME\t\$server_name;" >> $fastcgi
		echo -e "" >> $fastcgi
		echo -e "fastcgi_param\tHTTPS\t\t\$https;" >> $fastcgi
		echo -e "" >> $fastcgi
		echo -e "# PHP only, requried if PHP was built with --enable-force-cgi-redirect" >> $fastcgi
		echo -e "fastcgi_param\tREDIRECT_STATUS\t200;" >> $fastcgi

		nginx_config="/etc/nginx/sites-available/default"
		mv $nginx_config /etc/nginx/sites-available/default.old	
		echo "upstream php-handler {" > $nginx_config
		echo "        server 127.0.0.1:9000;" >> $nginx_config
		echo "        #server unix:/var/run/php5-fpm.sock;" >> $nginx_config
		echo "}" >> $nginx_config
		echo " " >> $nginx_config
		echo "server {" >> $nginx_config
		echo "        listen 80;" >> $nginx_config
		echo "        server_name "$server_ip";" >> $nginx_config
		echo "        #return 301 https://\$server_name\$request_uri;  # enforce https" >> $nginx_config
		echo "        # Path to the root of your installation" >> $nginx_config
       		echo "        root "$http_dir";" >> $nginx_config
       	        echo " " >> $nginx_config
                echo "        client_max_body_size 1000M; # set max upload size" >> $nginx_config
                echo "        fastcgi_buffers 64 4K;" >> $nginx_config
                echo " " >> $nginx_config
                echo "        rewrite ^/caldav(.*)$ /remote.php/caldav\$1 redirect;" >> $nginx_config
                echo "        rewrite ^/carddav(.*)$ /remote.php/carddav\$1 redirect;" >> $nginx_config
                echo "        rewrite ^/webdav(.*)$ /remote.php/webdav\$1 redirect;" >> $nginx_config
                echo " " >> $nginx_config
                echo "        index index.php index.html index.htm;" >> $nginx_config
                echo "        error_page 403 /core/templates/403.php;" >> $nginx_config
                echo "        error_page 404 /core/templates/404.php;" >> $nginx_config
                echo " " >> $nginx_config
                echo "        location = /robots.txt {" >> $nginx_config
                echo "            allow all;" >> $nginx_config
                echo "            log_not_found off;" >> $nginx_config
                echo "            access_log off;" >> $nginx_config
                echo "        }" >> $nginx_config
                echo " " >> $nginx_config
                echo "        location ~ ^/(?:\.htaccess|data|config|db_structure\.xml|README) {" >> $nginx_config
                echo "                deny all;" >> $nginx_config
                echo "        }" >> $nginx_config
                echo " " >> $nginx_config
                echo "        location / {" >> $nginx_config
                echo "                # The following 2 rules are only needed with webfinger" >> $nginx_config
                echo "                rewrite ^/.well-known/host-meta /public.php?service=host-meta last;" >> $nginx_config
                echo "                rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json last;" >> $nginx_config
                echo " " >> $nginx_config
                echo "                rewrite ^/.well-known/carddav /remote.php/carddav/ redirect;" >> $nginx_config
                echo "                rewrite ^/.well-known/caldav /remote.php/caldav/ redirect;" >> $nginx_config
                echo " " >> $nginx_config
                echo "                rewrite ^(/core/doc/[^\/]+/)$ \$1/index.html;" >> $nginx_config
                echo " " >> $nginx_config
                echo "                try_files \$uri \$uri/ index.php;" >> $nginx_config
                echo "        }" >> $nginx_config
                echo " " >> $nginx_config
                echo "        location ~ [^/].php(/|$) {" >> $nginx_config
                echo "                fastcgi_split_path_info ^(.+?.php)(/.*)$;" >> $nginx_config
                echo "                if (!-f \$document_root\$fastcgi_script_name) {" >> $nginx_config
                echo "                  return 404;" >> $nginx_config
                echo "                }" >> $nginx_config
                echo "                fastcgi_pass unix:/var/run/php5-fpm.sock;" >> $nginx_config
                echo "                fastcgi_index index.php;" >> $nginx_config
                echo "                include fastcgi_params;" >> $nginx_config
                echo "        }" >> $nginx_config
                echo " " >> $nginx_config
                echo "        # Optional: set long EXPIRES header on static assets" >> $nginx_config
                echo "        location ~* \.(?:jpg|jpeg|gif|bmp|ico|png|css|js|swf)$ {" >> $nginx_config
                echo "                expires 30d;" >> $nginx_config
                echo "                # Optional: Don't log access to assets" >> $nginx_config
                echo "                access_log off;" >> $nginx_config
		echo "		}" >> $nginx_config
		echo "}" >> $nginx_config
		echo " " >> $nginx_config
		case "$setup_ssl" in
		y|yes )
			echo "server {" >> $nginx_config
			echo "        listen 443 ssl;" >> $nginx_config
			echo "        server_name "$server_ip";" >> $nginx_config
			echo " " >> $nginx_config
			echo "        ssl_certificate /etc/nginx/cert.pem;" >> $nginx_config
			echo "        ssl_certificate_key /etc/nginx/cert.key;" >> $nginx_config
			echo " " >> $nginx_config
			echo "        # Path to the root of your installation" >> $nginx_config
			echo "        root "$http_dir";" >> $nginx_config
			echo " " >> $nginx_config
			echo "        client_max_body_size 1000M; # set max upload size" >> $nginx_config
			echo "        fastcgi_buffers 64 4K;" >> $nginx_config
			echo " " >> $nginx_config
			echo "        rewrite ^/caldav(.*)$ /remote.php/caldav\$1 redirect;" >> $nginx_config
			echo "        rewrite ^/carddav(.*)$ /remote.php/carddav\$1 redirect;" >> $nginx_config
			echo "        rewrite ^/webdav(.*)$ /remote.php/webdav\$1 redirect;" >> $nginx_config
			echo " " >> $nginx_config
			echo "        index index.php index.html index.htm;" >> $nginx_config
			echo "        error_page 403 /core/templates/403.php;" >> $nginx_config
			echo "        error_page 404 /core/templates/404.php;" >> $nginx_config
			echo " " >> $nginx_config
			echo "        location = /robots.txt {" >> $nginx_config
			echo "            allow all;" >> $nginx_config
			echo "            log_not_found off;" >> $nginx_config
			echo "            access_log off;" >> $nginx_config
			echo "        }" >> $nginx_config
			echo " " >> $nginx_config
			echo "        location ~ ^/(?:\.htaccess|data|config|db_structure\.xml|README) {" >> $nginx_config
			echo "                deny all;" >> $nginx_config
			echo "        }" >> $nginx_config
			echo " " >> $nginx_config
			echo "        location / {" >> $nginx_config
			echo "                # The following 2 rules are only needed with webfinger" >> $nginx_config
			echo "                rewrite ^/.well-known/host-meta /public.php?service=host-meta last;" >> $nginx_config
			echo "                rewrite ^/.well-known/host-meta.json /public.php?service=host-meta-json last;" >> $nginx_config
			echo " " >> $nginx_config
			echo "                rewrite ^/.well-known/carddav /remote.php/carddav/ redirect;" >> $nginx_config
			echo "                rewrite ^/.well-known/caldav /remote.php/caldav/ redirect;" >> $nginx_config
			echo " " >> $nginx_config
			echo "                rewrite ^(/core/doc/[^\/]+/)$ \$1/index.html;" >> $nginx_config
			echo " " >> $nginx_config
			echo "                try_files \$uri \$uri/ index.php;" >> $nginx_config
			echo "        }" >> $nginx_config
			echo " " >> $nginx_config
			echo "        location ~ [^/].php(/|$) {" >> $nginx_config
			echo "                fastcgi_split_path_info ^(.+?.php)(/.*)$;" >> $nginx_config
			echo "                if (!-f \$document_root\$fastcgi_script_name) {" >> $nginx_config
			echo "                	return 404;" >> $nginx_config
			echo "                }" >> $nginx_config
			echo "                fastcgi_pass unix:/var/run/php5-fpm.sock;" >> $nginx_config
			echo "                fastcgi_index index.php;" >> $nginx_config
			echo "		      include fastcgi_params;" >> $nginx_config
			echo "        }" >> $nginx_config
			echo " " >> $nginx_config
			echo "        # Optional: set long EXPIRES header on static assets" >> $nginx_config
			echo "        location ~* \.(?:jpg|jpeg|gif|bmp|ico|png|css|js|swf)$ {" >> $nginx_config
			echo "                expires 30d;" >> $nginx_config
			echo "                # Optional: Don't log access to assets" >> $nginx_config
			echo "                access_log off;" >> $nginx_config
			echo "        }" >> $nginx_config
			echo " " >> $nginx_config
			echo "}" >> $nginx_config
			;;
		esac
		cp /etc/dphys-swapfile /etc/dphys-swapfile.old
		awk '{
			if($0~/CONF_SWAPSIZE/)
				print "CONF_SWAPSIZE=512";
			else 
				print $0;
		}' /etc/dphys-swapfile.old > /etc/dphys-swapfile
		php_conf="/etc/php5/fpm/pool.d/www.conf"
		cp $php_conf /etc/php5/fpm/pool.d/www.conf.old
		awk '{
			if($0~/listen\.owner/)
				print "listen.owner = www-data";
			else if($0~/listen\.group/)
				print "listen.group = www-data";
			else
				print $0;
			}' /etc/php5/fpm/pool.d/www.conf.old > $php_conf
		mysql_secure_installation
		case "$setup_ssl" in
		y|yes )
                        openssl req -new -x509 -days 730 -nodes -out /etc/nginx/cert.pem -keyout /etc/nginx/cert.key
                        chmod 600 /etc/nginx/cert.pem
                        chmod 600 /etc/nginx/cert.key
                        ;;
                * )
                        echo "Skipping SLL setup..."
                        ;;
                esac
		/etc/init.d/php5-fpm restart
		mkdir -p $http_dir
		chown -R root $http_dir
		chgrp -R www-data $http_dir
		chmod -R 750 $http_dir
		chmod g+s $http_dir
		echo "<head><TITLE>SUCCESS</TITLE></head><BODY>Congratulations, your webserver is working!<p>-The Engineering Hitman<p><?PHP phpinfo();?></BODY>" > $http_dir/index.php
		/etc/init.d/nginx restart
	else
		echo "This option must be run as root. Please try again with sudo."
	fi
	;;
* )
	echo "Exiting without changes."
	;;
esac
shopt -u nocasematch
