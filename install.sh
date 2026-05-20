#!/bin/bash
# MedusaXD Telegram Bot Installer — self-contained, no Jubair URLs
set -e

C_RESET='\033[0m'; C_GREEN='\033[0;32m'; C_CYAN='\033[0;36m'; C_RED='\033[0;31m'; C_YELLOW='\033[1;33m'
log()  { echo -e "${C_CYAN}[INFO]${C_RESET} $1"; }
ok()   { echo -e "${C_GREEN}[OK]${C_RESET}   $1"; }
err()  { echo -e "${C_RED}[ERR]${C_RESET}  $1"; }
step() { echo -e "\n${C_YELLOW}>>> $1${C_RESET}"; }

BOT_DIR="/root/.ssbot"
BOT_PYC_URL="${BOT_PYC_URL:-https://raw.githubusercontent.com/greatautomate/Paid/refs/heads/main/bot/bot.pyc}"
SERVICE_NAME="sensi-bot"

clear
echo -e "${C_GREEN}===================================================="
echo -e "        MedusaXD Telegram Bot Installer"
echo -e "====================================================${C_RESET}"

step "Stopping existing service (if running)"
systemctl stop "$SERVICE_NAME" 2>/dev/null || true

step "Preparing directory"
mkdir -p "$BOT_DIR"
cd "$BOT_DIR"

step "Setting up Python venv"
if [ ! -x "$BOT_DIR/venv/bin/python3" ]; then
    apt-get install -y python3-venv >/dev/null 2>&1 || true
    python3 -m venv venv
    ok "venv created"
else
    log "venv exists, reusing"
fi

step "Installing Python dependencies"
"$BOT_DIR/venv/bin/pip" install --quiet --upgrade pip
"$BOT_DIR/venv/bin/pip" install --quiet \
    "anyio==4.13.0" \
    "certifi==2026.4.22" \
    "exceptiongroup==1.3.1" \
    "h11==0.16.0" \
    "httpcore==1.0.9" \
    "httpx==0.28.1" \
    "idna==3.15" \
    "psutil==7.2.2" \
    "python-telegram-bot==22.7" \
    "typing_extensions==4.15.0"
ok "dependencies installed"

step "Downloading MedusaXD bot binary"
curl -sLf -o "$BOT_DIR/bot.pyc" "$BOT_PYC_URL"
[ -s "$BOT_DIR/bot.pyc" ] || { err "bot.pyc download failed"; exit 1; }
ok "bot.pyc downloaded ($(stat -c%s "$BOT_DIR/bot.pyc") bytes)"

step "Bot configuration"
read -p "Enter Telegram Bot Token (from @BotFather): " BOT_TOKEN
if [ -z "$BOT_TOKEN" ]; then
    err "Bot token cannot be empty."
    exit 1
fi

read -p "Enter Admin Telegram ID: " ADMIN_ID
if [ -z "$ADMIN_ID" ]; then
    err "Admin Telegram ID cannot be empty."
    exit 1
fi

echo "$BOT_TOKEN" > "$BOT_DIR/token.txt"
chmod 600 "$BOT_DIR/token.txt"
echo "$ADMIN_ID" > "$BOT_DIR/admins.txt"
ok "bot token and admin saved"

step "Installing systemd service"
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=MedusaXD Telegram Bot
After=network.target

[Service]
User=root
WorkingDirectory=${BOT_DIR}
ExecStart=${BOT_DIR}/venv/bin/python3 ${BOT_DIR}/bot.pyc
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
systemctl restart "$SERVICE_NAME"
sleep 2

if systemctl is-active --quiet "$SERVICE_NAME"; then
    ok "Service is running ✓"
    echo
    echo -e "${C_GREEN}====================================================${C_RESET}"
    echo -e "${C_GREEN}  MedusaXD Bot installed. Open Telegram and /start${C_RESET}"
    echo -e "${C_GREEN}====================================================${C_RESET}"
else
    err "Service failed to start. Check: systemctl status $SERVICE_NAME"
    systemctl status "$SERVICE_NAME" --no-pager -l | tail -20
    exit 1
fi
