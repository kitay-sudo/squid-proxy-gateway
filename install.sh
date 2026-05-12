#!/bin/bash

#===============================================================================
#  🦑 squid-proxy-gateway installer
#  One-command Squid proxy setup with authentication
#
#  Usage:
#    Interactive (recommended):
#      curl -fsSL <url>/install.sh -o install.sh && sudo bash install.sh
#
#    Piped (will read from /dev/tty if available):
#      curl -fsSL <url>/install.sh | sudo bash
#
#    Non-interactive (env vars):
#      curl -fsSL <url>/install.sh | sudo PROXY_USER=alice PROXY_PASS=secret PROXY_PORT=3128 bash
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

# Detect input source: prefer /dev/tty so interactive read works even
# when the script is piped via `curl | bash`.
INPUT_TTY=""
if [[ -r /dev/tty ]]; then
    INPUT_TTY="/dev/tty"
fi

prompt() {
    # prompt VAR "message" [-s]
    local __var="$1"
    local __msg="$2"
    local __silent="$3"
    local __value=""

    if [[ -n "$INPUT_TTY" ]]; then
        if [[ "$__silent" == "-s" ]]; then
            read -s -r -p "$__msg" __value < "$INPUT_TTY"
            echo "" > /dev/tty
        else
            read -r -p "$__msg" __value < "$INPUT_TTY"
        fi
    fi

    printf -v "$__var" '%s' "$__value"
}

# Generate a strong random password (used when no TTY and no PROXY_PASS env)
gen_password() {
    if command -v openssl &> /dev/null; then
        openssl rand -base64 24 | tr -d '/+=' | cut -c1-24
    else
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24
    fi
}

# --- Username ---------------------------------------------------------------
if [[ -z "$PROXY_USER" ]]; then
    prompt PROXY_USER "👤 Proxy username [proxyuser]: "
fi
PROXY_USER=${PROXY_USER:-proxyuser}

# --- Password ---------------------------------------------------------------
if [[ -z "$PROXY_PASS" ]]; then
    if [[ -n "$INPUT_TTY" ]]; then
        while true; do
            prompt PROXY_PASS "🔑 Proxy password: " -s
            if [[ -z "$PROXY_PASS" ]]; then
                echo -e "${RED}Password cannot be empty${NC}"
            else
                break
            fi
        done
    else
        # No TTY and no env var — auto-generate so the script never silently
        # creates a user with an empty password.
        PROXY_PASS="$(gen_password)"
        AUTO_PASS=1
        echo -e "${YELLOW}⚠️  No TTY detected and PROXY_PASS not set — generated a random password.${NC}"
    fi
fi

# --- Port -------------------------------------------------------------------
if [[ -z "$PROXY_PORT" ]]; then
    prompt PROXY_PORT "🔌 Port [3128]: "
fi
PROXY_PORT=${PROXY_PORT:-3128}

# Sanity check
if ! [[ "$PROXY_PORT" =~ ^[0-9]+$ ]] || (( PROXY_PORT < 1 || PROXY_PORT > 65535 )); then
    echo -e "${RED}❌ Invalid port: $PROXY_PORT${NC}"
    exit 1
fi

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
if [[ "$AUTO_PASS" == "1" ]]; then
    echo -e "   Pass: ${YELLOW}$PROXY_PASS${NC}  ${RED}(auto-generated — save it now!)${NC}"
else
    echo -e "   Pass: ${YELLOW}(hidden)${NC}"
fi
echo ""
echo -e "${CYAN}🔗 Connection string:${NC}"
echo ""
if [[ "$AUTO_PASS" == "1" ]]; then
    echo -e "   ${GREEN}export HTTPS_PROXY=\"http://$PROXY_USER:$PROXY_PASS@$SERVER_IP:$PROXY_PORT\"${NC}"
else
    echo -e "   ${GREEN}export HTTPS_PROXY=\"http://$PROXY_USER:PASSWORD@$SERVER_IP:$PROXY_PORT\"${NC}"
fi
echo ""
echo -e "${CYAN}🧪 Test command:${NC}"
echo ""
echo -e "   ${GREEN}HTTPS_PROXY=\"http://$PROXY_USER:PASSWORD@$SERVER_IP:$PROXY_PORT\" curl https://ifconfig.me${NC}"
echo ""
echo -e "${CYAN}📝 Logs:${NC} tail -f /var/log/squid/access.log"
echo ""
