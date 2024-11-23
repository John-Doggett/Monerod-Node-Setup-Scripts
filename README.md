# Monerod-Node-Setup-Scripts
Automatically create a Monerod node with HTTPS on Debian. This script configures a public monero node with HTTPS enabled. 
It uses Caddy to create a public information site on your node, as well as renewing LetsEncrypt certificates.

Run ./setup_monerod.sh as root

Be sure you have a valid DNS name pointing to your server before running, and ports 80, 443, 18080, and 18089 are unblocked.

The config will ask you for:
The DNS name of your server
The location of the server (for the website)
The name of the person to contact (for the website)
The email of the person to contact (for the website)
Whether to prune the blockchain or not
Whether to bind the server to ipv4 or not (binds to 0.0.0.0).
Whether to bind the server to ipv6 or not (binds to ::).

Caddy will host a website at https://[Your Domain]. It gives instructions for connecting to your node.
If you have an existing configuration for caddy, the script backups the old config as Caddyfile.old. You will need to manually merge the configs.

![Site example](https://github.com/John-Doggett/Monerod-Node-Setup-Scripts/blob/main/docs/site.png?raw=true)
Example Node Site

![config example](https://github.com/John-Doggett/Monerod-Node-Setup-Scripts/blob/main/docs/config.png?raw=true)
Config screen
