#!/bin/bash
# DNS + Web Server Debian 12 - lab-smk.xyz (192.168.30.10)
# Upload ke GitHub: https://github.com/username/lab-smk-server

set -e  # Stop on error

echo "🚀 Installing DNS + Web Server untuk lab-smk.xyz..."

# Update system
apt update && sudo apt upgrade -y

# Install BIND9 + Apache
apt install -y bind9 sudo apache2 openssl

# 1. DNS ZONE lab-smk.xyz
sudo mkdir -p /etc/bind/zones
cat > /tmp/db.lab-smk.xyz << 'EOF'
$TTL    604800
@       IN      SOA     lab-smk.xyz. root.lab-smk.xyz. (
                     2         ; Serial
                604800         ; Refresh
                 86400         ; Retry
               2419200         ; Expire
                604800 )       ; Negative Cache TTL
;
@       IN      NS      lab-smk.xyz.
ns      IN      A       192.168.30.10
@       IN      A       192.168.30.10
www     IN      A       192.168.30.10
monitor IN      A       192.168.30.10
EOF
sudo cp /tmp/db.lab-smk.xyz /etc/bind/zones/
sudo chown bind:bind /etc/bind/zones/db.lab-smk.xyz
sudo chmod 644 /etc/bind/zones/db.lab-smk.xyz

# Konfigurasi
DOMAIN="lab-smk.xyz"
ZONE_CONF="zone \"$DOMAIN\" { type master; file \"/etc/bind/zones/db.$DOMAIN\"; };"
FILE="/etc/bind/named.conf.local"

# Eksekusi: Cek dulu supaya tidak double, lalu masukkan ke baris baru
grep -q "$DOMAIN" "$FILE" || echo -e "\n$ZONE_CONF" | sudo tee -a "$FILE"

echo "Konfigurasi $DOMAIN telah ditambahkan ke $FILE"

# Secure DNS (disable recursion VLAN 20)
sudo sed -i '/options {/a\    recursion yes;\n    allow-recursion { 192.168.30.0/24; };\n    allow-query { localhost; 192.168.30.0/24; };' /etc/bind/named.conf.options

sudo systemctl restart bind9 && sudo systemctl enable bind9

# 2. Web Server + HTTPS Self-Signed
sudo sh -c 'echo -e "anjay bisa" > /var/www/html/index.html'

# Generate SSL
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/apache-selfsigned.key \
  -out /etc/ssl/certs/apache-selfsigned.crt \
  -subj "/C=ID/ST=Jakarta/L=Jakarta/O=LabSMK/CN=lab-smk.xyz"

sudo a2enmod ssl rewrite
sudo a2ensite default-ssl
sudo systemctl restart apache2 && sudo systemctl enable apache2

echo "✅ DNS+Web Selesai!"
echo "🌐 Test:"
echo "  nslookup www.lab-smk.xyz 192.168.30.10"
echo "  curl -k https://192.168.30.10"
