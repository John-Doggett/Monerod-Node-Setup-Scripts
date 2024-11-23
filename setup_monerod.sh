#! /bin/bash

echo "----Monerod setup script for debian based systems----"
echo "           Jack Doggett - jack@doggett.tech          "

if [ "$EUID" -ne 0 ]
  then echo "You must run as root"
  exit 1
fi

echo "Please make sure you have a domain name pointing towards your server, and TCP port 80,443,18080, and 18089 are open."
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
    echo "What is the DNS record of your server?"

    read dns_name

    echo "What is the location of your server?"

    read server_location

    echo "What is the contact name of your server?"

    read owner_name

    echo "What is the contact email of your server?"

    read owner_email

    echo "Prune blockchain? Y/N"

    read answer

    if [ "$answer" != "${answer#[Yy]}" ] ;then
        prune=true
    else
        prune=false
    fi

    echo "Bind to IPv4? Y/N"

    read answer

    if [ "$answer" != "${answer#[Yy]}" ] ;then
        ipv4=true
    else
        ipv4=false
    fi

    echo "Bind to IPv6? Y/N"

    read answer

    if [ "$answer" != "${answer#[Yy]}" ] ;then
        ipv6=true
    else
        ipv6=false
    fi

    echo "Installing to $dns_name"
    echo "Server location: $server_location"
    echo "Owner name: $owner_name"
    echo "Owner email: $owner_email"
    echo "Pruning blockchain: $prune"
    echo "Bind IPv4: $ipv4"
    echo "Bind IPV6: $ipv6"

    if [ $ipv4 == false ] && [ $ipv6 == false ] ; then
        echo "Either ipv4 or ipv6 must be enabled"
        valid=false
    else
        valid=true
    fi

    echo "Configuration Okay? Y/N"

    read answer

    if [ "$answer" != "${answer#[Yy]}" ] && [ $valid == true ] ;then
        break;
    fi
done
echo "Configuration complete, now installing"
current_dir=$(pwd)

echo "----Installing required packages----"
apt-get install -y wget bzip2 caddy inotify-tools

echo "----Copying base config files----"
cp -v config-base/monerod.conf .
cp -v config-base/index.html .
cp -v config-base/watch_certificates_xmr.sh .

echo "----Downloading and install monero----"
temp_dir=$(mktemp -d)
cd $temp_dir
wget https://downloads.getmonero.org/linux64
tar -xjvf linux64
rm -v linux64
cp -rv monero-x86_64-linux-gnu-*/monero* /usr/local/bin/
rm -rfv monero-x86_64-linux-gnu-*
cd $current_dir
rmdir -v $temp_dir

echo "----Setting up monerod user and files----"
# Create a system user and group to run monerod
addgroup --system monero
adduser --system --home /var/lib/monero --ingroup monero --disabled-login monero

# Create necessary directories for monerod
mkdir -v /var/lib/monero
mkdir -v /var/run/monero
mkdir -v /var/log/monero
mkdir -v /etc/monero
mkdir -v /var/lib/monero/certificates

# Create PID and last update file
touch /var/run/monero/monero.pid
touch /var/lib/monero/certificates/last-update
echo "1" | tee /var/lib/monero/certificates/last-update

# Set permissions for new directories
chown -R monero:monero /var/lib/monero
chmod -v 710 /var/lib/monero
chmod -v 710 /var/lib/monero/certificates
chown -R -v monero:monero /var/run/monero
chmod -v 710 /var/run/monero
chown -R -v monero:monero /var/log/monero
chmod -v 710 /var/log/monero
chown -R monero:monero /etc/monero
chmod -v 710 /etc/monero

echo "----Configuring monerod.conf----"
config_file="monerod.conf"

# Uncomment ipv4 bind
if [ $ipv4 = true ]; then
  sed -i 's/^#\(p2p-bind-ip=0\.0\.0\.0\)/\1/' $config_file
  sed -i 's/^#\(rpc-bind-ip=0\.0\.0\.0\)/\1/' $config_file
fi

# Uncomment ipv6 bind
if [ $ipv6 = true ]; then
  sed -i 's/^#\(p2p-use-ipv6=true\)/\1/' $config_file
  sed -i 's/^#\(p2p-bind-ipv6-address=::\)/\1/' $config_file
  sed -i 's/^#\(rpc-use-ipv6=true\)/\1/' $config_file
  sed -i 's/^#\(rpc-bind-ipv6-address=::\)/\1/' $config_file
fi

# Uncomment prune-blockchain if prune is true
if [ $prune = true ]; then
  sed -i 's/^#\(prune-blockchain=true\)/\1/' $config_file
fi

# Replace DOMAINNAME with dns_name in rpc settings
sed -i "s/DOMAINNAME/$dns_name/g" $config_file

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

echo "----Configuring node website----"
mkdir -v /srv/${dns_name}
html_file="index.html"

# Replace DOMAINNAME with dns_name in website
sed -i "s/DOMAINNAME/$dns_name/g" $html_file

# Replace NODETYPE with Pruned or Full in website
if [ $prune = true ]; then
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

# Print html file
cat $html_file

# Copy over html file
cp -v $html_file /srv/${dns_name}

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

echo "----Installation complete----"
echo ""
echo ""

echo "Congratulations! Your monero node with HTTPS is set up! Please wait a minute for the node to start"
echo "See:"
echo "View your node website on https://${dns_name}"
echo "/etc/monero/monerod.conf for your monerod.config"
echo "/srv/${dns_name}/index.html for your node website"
echo "/var/log/monero for your monero node logs"
echo "/var/lib/monero for your monero node database"
echo "Please check /etc/caddy/Caddyfile.old if you previously had a caddy configuration, you must merge the config with the new Caddyfile"
