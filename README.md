# Monerod-Node-Setup-Scripts
Automatically create a public Monerod node on Debian. This script configures a public monero node with HTTPS and Tor. 
It uses Caddy to create a public website on your node, as well as renewing LetsEncrypt certificates.

Run ./setup_monerod.sh as root

At a minimum you need ports 18080 and 18089 open for a basic monero node.
If you want to use HTTPS, you need ports 80 and 443 open, and a domain name pointing towards your server.

The script can setup a monero node in the following configurations:
HTTPS and Tor enabled
HTTPS enbled, Tor disabled
HTTPS disabled, Tor enabled
HTTPS and Tor disabled

Caddy will host a website at https://[Your Domain]. It gives instructions for connecting to your node.
If you have an existing configuration for caddy, the script backups the old config as Caddyfile.old. You will need to manually merge the configs.

![Site example](https://github.com/John-Doggett/Monerod-Node-Setup-Scripts/blob/main/docs/site.png?raw=true)
Example Node Site

![config example](https://github.com/John-Doggett/Monerod-Node-Setup-Scripts/blob/main/docs/config.png?raw=true)
Config screen
