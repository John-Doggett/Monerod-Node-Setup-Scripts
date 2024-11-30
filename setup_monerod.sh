#! /bin/bash

echo "----Monerod setup script for debian based systems----"
echo "           Jack Doggett - jack@doggett.tech          "
echo "                    Version 0.3                      "

if [ "$EUID" -ne 0 ]
  then echo "You must run as root"
  exit 1
fi

# Get the architecture
arch=$(uname -m)

# Determine the Monero release based on the architecture
case $arch in
    x86_64)
        release="linux64"  # 64-bit x86
        ;;
    i686 | i386)
        release="linux32"     # 32-bit x86
        ;;
    aarch32 | arm32 | armv7*)
        release="linuxarm7"   # 32-bit ARM
        ;;
    aarch64 | arm64 | armv8*)
        release="linuxarm8"   # 64-bit ARM
        ;;
    *)
        echo "Unsupported architecture: $arch"
        exit 1
        ;;
esac

# Print the determined release
echo "Detected architecture: $arch"
echo "Monero release to download: $release"

# Download the appropriate Monero release (example URL)
download_url="https://downloads.getmonero.org/${release}"

# Get which package manager we use
if command -v apt-get &> /dev/null; then
    echo "This system uses apt."
    install_command="apt-get"
elif command -v dnf &> /dev/null; then
    echo "This system uses dnf."
    echo "!!!!!WARNING: this script is not fully implemented for fedora based systems. You will encounter selinux alerts!!!!!"
    install_command="dnf"
else
    echo "Neither apt nor dnf found."
    exit 1
fi

echo "Please make sure TCP ports 18080 and 18089 are open. These are necessary for monerod."
echo "If you plan to use HTTPS with your monero node, please make sure TCP ports 80 and 443 are open and you have a valid domain name pointing towards your server."
echo "Continue? Y/N:"

read answer

if [ "$answer" != "${answer#[Yy]}" ] ;then
    echo "Continuing with installation..."
else
    echo "Exiting script..."
    exit 0
fi

while true; do
    echo "----Configuration Questions----"

    echo "Enable HTTPS (Sets up public website and TLS on monerod)? Y/N"

    read answer

    if [ "$answer" != "${answer#[Yy]}" ]; then
        https=true
    else
        https=false
    fi

    if [ $https == true ]; then

	echo "The following questions are needed to setup HTTPS for your monero node. A public website to help clients connect to your monero node will be created."

        echo "HTTPS: What is the DNS record of your server?"

        read dns_name

        echo "HTTPS: What is the location of your server?"

        read server_location

        echo "HTTPS: What is the contact name of your server?"

        read owner_name

        echo "HTTPS: What is the contact email of your server?"

        read owner_email

    fi

    echo "Enable Tor access? Y/N"

    read answer

    if [ "$answer" != "${answer#[Yy]}" ]; then
        tor=true
    else
        tor=false
    fi

    echo "Prune blockchain? Y/N"

    read answer

    if [ "$answer" != "${answer#[Yy]}" ]; then
        prune=true
    else
        prune=false
    fi

    echo "Bind to IPv4? Y/N"

    read answer

    if [ "$answer" != "${answer#[Yy]}" ]; then
        ipv4=true
    else
        ipv4=false
    fi

    echo "Bind to IPv6? Y/N"

    read answer

    if [ "$answer" != "${answer#[Yy]}" ]; then
        ipv6=true
    else
        ipv6=false
    fi

    echo "Using HTTPS: $https"
    if [ $https == true ]; then
        echo "HTTPS: Installing to $dns_name"
        echo "HTTPS: Server location: $server_location"
        echo "HTTPS: Owner name: $owner_name"
        echo "HTTPS: Owner email: $owner_email"
    fi
    echo "Using Tor: $tor"
    echo "Pruning blockchain: $prune"
    echo "Bind IPv4: $ipv4"
    echo "Bind IPv6: $ipv6"

    if [ $ipv4 == false ] && [ $ipv6 == false ]; then
        echo "Either ipv4 or ipv6 must be enabled"
        valid=false
    else
        valid=true
    fi

    if [ $valid == true ]; then
        echo "Configuration Okay? Y/N"

        read answer

        if [ "$answer" != "${answer#[Yy]}" ]; then
            break;
        fi
    fi
done

echo "Configuration complete, now installing"

current_dir=$(pwd)

echo "----Installing required packages----"
$install_command install -y wget bzip2
if [ $? -ne 0 ]; then
    echo "Installing wget and bzip2 failed, exiting script."
    exit 1
fi

if [ $https == true ]; then
    $install_command install -y caddy inotify-tools
    if [ $? -ne 0 ]; then
        echo "Installing caddy and inotify-tools failed, exiting script."
        exit 1
    fi
fi

if [ $tor == true ]; then
    $install_command install -y tor
    if [ $? -ne 0 ]; then
        echo "Installing tor failed, exiting script."
        exit 1
    fi
fi

echo "----Copying base config files----"
cp -v config-base/monerod.conf .

if [ $https == true ]; then
    cp -v config-base/index.html .
    cp -v config-base/watch_certificates_xmr.sh .
fi

echo "----Downloading and install monero----"
temp_dir=$(mktemp -d)
cd $temp_dir
wget $download_url
tar -xjvf $release
rm -v $release
cp -rv monero-*/monero* /usr/local/bin/
rm -rfv monero-*
cd $current_dir
rmdir -v $temp_dir

echo "----Setting up monerod user and files----"
# Create a system user and group to run monerod
groupadd --system monero
useradd --system --home-dir /var/lib/monero --gid monero monero
usermod -s /sbin/nologin monero
usermod -p '!' monero

# Create necessary directories for monerod
mkdir -v /var/lib/monero
mkdir -v /var/run/monero
mkdir -v /var/log/monero
mkdir -v /etc/monero
if [ $https == true ]; then
    mkdir -v /var/lib/monero/certificates
fi

# Create PID and last update file
touch /var/run/monero/monerod.pid
if [ $https == true ]; then
    touch /var/lib/monero/certificates/last-update
    echo "1" | tee /var/lib/monero/certificates/last-update
fi

# Set permissions for new directories
chown -R monero:monero /var/lib/monero
chmod -v 710 /var/lib/monero
if [ $https == true ]; then
    chmod -v 710 /var/lib/monero/certificates
fi
chown -R -v monero:monero /var/run/monero
chmod -v 710 /var/run/monero
chown -R -v monero:monero /var/log/monero
chmod -v 710 /var/log/monero
chown -R monero:monero /etc/monero
chmod -v 710 /etc/monero

if [ $tor == true ]; then

    echo "----Configuring tor----"

    # Update tor config
    echo "## Tor Monero RPC HiddenService" | tee -a /etc/tor/torrc
    echo "HiddenServiceDir /var/lib/tor/monerod" | tee -a /etc/tor/torrc
    echo "HiddenServicePort 18084 127.0.0.1:18084    # interface for P2P" | tee -a /etc/tor/torrc
    echo "HiddenServicePort 18089 127.0.0.1:18089    # interface for RPC" | tee -a /etc/tor/torrc

    if [ $https == true ]; then
        echo "HiddenServicePort 80 127.0.0.1:8080    # interface for website" | tee -a /etc/tor/torrc
    fi

    # Start tor service
    systemctl enable tor
    systemctl start tor

    # Restart tor to generate keys
    sleep 10
    systemctl restart tor

    # Get onion address
    sleep 10
    onion_address=$(cat /var/lib/tor/monerod/hostname)
    echo "Onion Address: $onion_address"
fi


echo "----Configuring monerod.conf----"
config_file="monerod.conf"

# Uncomment ipv4 bind
if [ $ipv4 == true ]; then
  sed -i 's/^#\(p2p-bind-ip=0\.0\.0\.0\)/\1/' $config_file
  sed -i 's/^#\(rpc-bind-ip=0\.0\.0\.0\)/\1/' $config_file
fi

# Uncomment ipv6 bind
if [ $ipv6 == true ]; then
  sed -i 's/^#\(p2p-use-ipv6=true\)/\1/' $config_file
  sed -i 's/^#\(p2p-bind-ipv6-address=::\)/\1/' $config_file
  sed -i 's/^#\(rpc-use-ipv6=true\)/\1/' $config_file
  sed -i 's/^#\(rpc-bind-ipv6-address=::\)/\1/' $config_file
fi

# Uncomment prune-blockchain if prune is true
if [ $prune == true ]; then
  sed -i 's/^#\(prune-blockchain=true\)/\1/' $config_file
fi

# Update config for HTTPS settings if https is true
if [ $https == true ]; then

    # Uncomment certificate settings
    sed -i 's/^#\(rpc-ssl-private-key=\/var\/lib\/monero\/certificates\/DOMAINNAME.key\)/\1/' $config_file
    sed -i 's/^#\(rpc-ssl-certificate=\/var\/lib\/monero\/certificates\/DOMAINNAME.crt\)/\1/' $config_file

    # Replace DOMAINNAME with dns_name in rpc settings
    sed -i "s/DOMAINNAME/$dns_name/g" $config_file

fi

# Update config for Tor settings if tor is true
if [ $tor == true ]; then

    # Uncomment tor settings
    sed -i 's/^#\(tx-proxy=tor,127.0.0.1:9050,disable_noise\)/\1/' $config_file
    sed -i 's/^#\(anonymous-inbound=ONIONADDRESS:18084,127.0.0.1:18084\)/\1/' $config_file
    sed -i 's/^#\(pad-transactions=true\)/\1/' $config_file

    # Replace onion address
    sed -i "s/ONIONADDRESS/$onion_address/g" $config_file

fi

# Print config file
cat $config_file

# Copy over monerod conf and fix permissions
cp -v $config_file /etc/monero/monerod.conf
chown -v monero:monero /etc/monero/monerod.conf
chmod -v 640 /etc/monero/monerod.conf

echo "----Configuring monerod systemd service----"
cp -v config-base/monerod.service /etc/systemd/system/monerod.service
systemctl daemon-reload
systemctl enable monerod.service

if [ $https == true ]; then
    echo "----Configuring node website----"
    mkdir -v /srv/${dns_name}
    html_file="index.html"

    # Replace DOMAINNAME with dns_name in website
    sed -i "s/DOMAINNAME/$dns_name/g" $html_file

    # Replace NODETYPE with Pruned or Full in website
    if [ $prune == true ]; then
        sed -i "s/NODETYPE/Pruned/g" $html_file
    else
        sed -i "s/NODETYPE/Full/g" $html_file
    fi

    # Replace LOCATION with server_location in website
    sed -i "s/LOCATION/$server_location/g" $html_file

    # Replace OWNERNAME with owner_name in website
    sed -i "s/OWNERNAME/$owner_name/g" $html_file

    # Replace OWNEREMAIL with owner_email in website
    sed -i "s/OWNEREMAIL/$owner_email/g" $html_file

    if [ $tor == true ]; then
        # Uncomment onion address
        sed -i '/<!--<p><strong>Tor P2P:<\/strong> tcp:\/\/ONIONADDRESS:18084<\/p>-->/s/<!--\(.*\)-->/    \1   /' $html_file
        sed -i '/<!--<p><strong>Tor RPC:<\/strong> http:\/\/ONIONADDRESS:18089<\/p>-->/s/<!--\(.*\)-->/    \1   /' $html_file

        # Replace onion address
        sed -i "s/ONIONADDRESS/$onion_address/g" $html_file
    fi

    # Print html file
    cat $html_file

    # Copy over html file
    cp -v $html_file /srv/${dns_name}

    # Fix permissions of website directory
    chown -R -v caddy:caddy /srv/${dns_name}

    # Update caddy config
    caddy_config="/etc/caddy/Caddyfile"
    mv -v $caddy_config ${caddy_config}.old
    echo "${dns_name} {" | tee -a $caddy_config
    echo "	root * /srv/${dns_name}" | tee -a $caddy_config
    echo "	file_server" | tee -a $caddy_config
    echo "}" | tee -a $caddy_config
    echo "http://, https:// {" | tee -a $caddy_config
    echo "	redir https://${dns_name}" | tee -a $caddy_config
    echo "}" | tee -a $caddy_config

    if [ $tor == true ]; then
        echo ":8080 {" | tee -a $caddy_config
	echo "	root * /srv/${dns_name}" | tee -a $caddy_config
 	echo "	file_server" | tee -a $caddy_config
  	echo "	bind 127.0.0.1" | tee -a $caddy_config
   	echo "}" | tee -a $caddy_config
    fi

    systemctl restart caddy

    # Wait for caddy to get the new certificate
    echo "Waiting 60 seconds for certificate to renew"
    sleep 60

    echo "----Configuring certificate monitoring service----"

    # Replace DOMAINNAME with dns_name in monitoring script
    sed -i "s/DOMAINNAME/$dns_name/g" watch_certificates_xmr.sh

    # Copy over script and service
    cp -v watch_certificates_xmr.sh /usr/local/bin/
    cp -v config-base/cert-watcher-xmr.service /etc/systemd/system/

    # Enable execution of script
    chmod -v +x /usr/local/bin/watch_certificates_xmr.sh

    systemctl daemon-reload
    systemctl enable cert-watcher-xmr.service
    systemctl start cert-watcher-xmr.service

else
    systemctl start monerod.service
fi
echo "----Installation complete----"
echo ""
echo ""

echo "Congratulations! Your monero node is set up!"
if [ $https == true ]; then
    echo "Please wait a minute for your node to start"
fi
echo "See:"
if [ $https == true ]; then
    echo "View your node website on https://${dns_name}"
    echo "/srv/${dns_name}/index.html for your node website"
fi
echo "/etc/monero/monerod.conf for your monerod config"
echo "/var/log/monero for your monero node logs"
echo "/var/lib/monero for your monero node database"
if [ $https == true ]; then
    echo "Please check /etc/caddy/Caddyfile.old if you previously had a caddy configuration, you must merge the config with the new Caddyfile"
fi
