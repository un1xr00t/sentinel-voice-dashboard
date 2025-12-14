#!/bin/bash
# setup-server.sh
# SENTINEL Dashboard Server Setup Script for Ubuntu 22.04/24.04 (Linode, DigitalOcean, etc.)
# 
# Usage: 
#   1. Update the DOMAIN variable below
#   2. Run: chmod +x setup-server.sh && sudo ./setup-server.sh

set -e

# ========== CONFIGURATION ==========
# Change this to your domain (use DuckDNS for free domains)
DOMAIN="YOUR_DOMAIN_HERE"  # e.g., sentinel.duckdns.org or yourdomain.com

# Timezone (change to yours)
TIMEZONE="America/New_York"
# ===================================

echo "=========================================="
echo "  SENTINEL Dashboard Server Setup"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (use sudo)"
  exit 1
fi

# Validate domain is set
if [ "$DOMAIN" = "YOUR_DOMAIN_HERE" ]; then
  echo "❌ Please edit this script and set your DOMAIN first"
  exit 1
fi

echo "📋 Configuration:"
echo "   Domain: $DOMAIN"
echo "   Timezone: $TIMEZONE"
echo ""
read -p "Continue with this configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

# Set timezone
echo ""
echo "🕐 Setting timezone to $TIMEZONE..."
timedatectl set-timezone "$TIMEZONE"

# Update system
echo ""
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install required packages
echo ""
echo "📦 Installing nginx, certbot, and tools..."
apt install -y nginx certbot python3-certbot-nginx fail2ban ufw

# Create web directory
echo ""
echo "📁 Creating web directory..."
mkdir -p /var/www/sentinel

# Create placeholder index.html
cat > /var/www/sentinel/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
  <title>SENTINEL - Setup Required</title>
  <style>
    body { font-family: sans-serif; background: #0a0a0f; color: white; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
    .container { text-align: center; }
    h1 { color: #06b6d4; }
    p { color: #6b7280; }
    code { background: #1f2937; padding: 2px 8px; border-radius: 4px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>🛡️ SENTINEL</h1>
    <p>Server is ready! Replace this file with your dashboard.</p>
    <p>Upload your <code>index.html</code> to <code>/var/www/sentinel/</code></p>
  </div>
</body>
</html>
HTMLEOF

# Set permissions
chown -R www-data:www-data /var/www/sentinel
chmod -R 755 /var/www/sentinel

# Configure nginx
echo ""
echo "⚙️ Configuring nginx..."
cat > /etc/nginx/sites-available/sentinel << NGINXEOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/sentinel;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
}
NGINXEOF

# Enable site
ln -sf /etc/nginx/sites-available/sentinel /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx config
echo ""
echo "🔍 Testing nginx configuration..."
nginx -t

# Restart nginx
systemctl restart nginx
systemctl enable nginx

# Configure firewall
echo ""
echo "🔥 Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Configure fail2ban
echo ""
echo "🛡️ Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'FAIL2BANEOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
FAIL2BANEOF

systemctl restart fail2ban
systemctl enable fail2ban

# Get SSL certificate
echo ""
echo "🔒 Obtaining SSL certificate..."
echo "   Make sure your domain ($DOMAIN) points to this server's IP!"
echo ""
read -p "Domain DNS is configured and pointing here? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@$DOMAIN --redirect
  echo "✅ SSL certificate installed!"
else
  echo "⚠️ Skipping SSL. Run this later:"
  echo "   certbot --nginx -d $DOMAIN"
fi

# Print summary
echo ""
echo "=========================================="
echo "  ✅ SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "📋 Summary:"
echo "   Dashboard URL: https://$DOMAIN"
echo ""
echo "📁 File locations:"
echo "   Dashboard files: /var/www/sentinel/"
echo "   Nginx config: /etc/nginx/sites-available/sentinel"
echo ""
echo "🔧 Next steps:"
echo "   1. Upload your index.html to /var/www/sentinel/"
echo "   2. Update the API_URL and RETELL_TOKEN_URL in index.html"
echo "   3. Test the dashboard at https://$DOMAIN"
echo ""
echo "📜 SSL certificate auto-renews. Check with:"
echo "   certbot certificates"
echo ""
