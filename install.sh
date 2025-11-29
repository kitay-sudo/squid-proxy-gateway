#!/bin/bash

#===============================================================================
#  🦑 squid-proxy-gateway installer
#  One-command Squid proxy setup with authentication
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "  ██████  ██████  ██    ██ ██ ██████  "
echo " ██      ██    ██ ██    ██ ██ ██   ██ "
echo "  █████  ██    ██ ██    ██ ██ ██   ██ "
echo "      ██ ██ ▄▄ ██ ██    ██ ██ ██   ██ "
echo " ██████   ██████   ██████  ██ ██████  "
echo "             ▀▀                        "
echo -e "${NC}"
echo -e "${GREEN}🦑 Squid Proxy Gateway Installer${NC}"
echo "==========================================="
echo ""

# Check root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Run as root: sudo ./install.sh${NC}"
   exit 1
fi

# Get username
read -p "👤 Proxy username [proxyuser]: " PROXY_USER
PROXY_USER=${PROXY_USER:-proxyuser}

# Get password
while true; do
    read -s -p "🔑 Proxy password: " PROXY_PASS
    echo ""
    if [[ -z "$PROXY_PASS" ]]; then
        echo -e "${RED}Password cannot be empty${NC}"
    else
        break
    fi
done

# Get port
read -p "🔌 Port [3128]: " PROXY_PORT
PROXY_PORT=${PROXY_PORT:-3128}

echo ""
echo -e "${YELLOW}📦 Installing packages...${NC}"
apt update -qq
apt install -y squid apache2-utils > /dev/null 2>&1
echo -e "${GREEN}✓ Packages installed${NC}"

echo -e "${YELLOW}👤 Creating user...${NC}"
htpasswd -cb /etc/squid/passwords "$PROXY_USER" "$PROXY_PASS" > /dev/null 2>&1
echo -e "${GREEN}✓ User created${NC}"

echo -e "${YELLOW}⚙️  Configuring Squid...${NC}"
cp /etc/squid/squid.conf /etc/squid/squid.conf.backup 2>/dev/null || true

cat > /etc/squid/squid.conf << EOF
# Port
http_port $PROXY_PORT

# Authentication
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
auth_param basic realm Proxy
acl authenticated proxy_auth REQUIRED

# Access
http_access allow authenticated
http_access deny all

# Privacy
forwarded_for off
request_header_access Via deny all
request_header_access X-Forwarded-For deny all
request_header_access Proxy-Connection deny all

# Performance
cache deny all
EOF

echo -e "${GREEN}✓ Configuration complete${NC}"

echo -e "${YELLOW}🚀 Starting Squid...${NC}"
systemctl restart squid
systemctl enable squid > /dev/null 2>&1
echo -e "${GREEN}✓ Squid running${NC}"

# Firewall
if command -v ufw &> /dev/null; then
    echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
    ufw allow "$PROXY_PORT/tcp" > /dev/null 2>&1
    echo -e "${GREEN}✓ Port $PROXY_PORT opened${NC}"
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "YOUR_SERVER_IP")

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}✅ Installation complete!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${CYAN}📋 Your proxy settings:${NC}"
echo ""
echo -e "   Host: ${YELLOW}$SERVER_IP${NC}"
echo -e "   Port: ${YELLOW}$PROXY_PORT${NC}"
echo -e "   User: ${YELLOW}$PROXY_USER${NC}"
echo -e "   Pass: ${YELLOW}(hidden)${NC}"
echo ""
echo -e "${CYAN}🔗 Connection string:${NC}"
echo ""
echo -e "   ${GREEN}export HTTPS_PROXY=\"http://$PROXY_USER:PASSWORD@$SERVER_IP:$PROXY_PORT\"${NC}"
echo ""
echo -e "${CYAN}🧪 Test command:${NC}"
echo ""
echo -e "   ${GREEN}HTTPS_PROXY=\"http://$PROXY_USER:PASSWORD@$SERVER_IP:$PROXY_PORT\" curl https://ifconfig.me${NC}"
echo ""
echo -e "${CYAN}📝 Logs:${NC} tail -f /var/log/squid/access.log"
echo ""
