#!/bin/bash

echo -n "Enter email: "
read EMAIL

echo -n "Enter password: "
read -s PASSWORD
echo ""

docker run -d --restart unless-stopped \
    packetshare/packetshare \
    -accept-tos \
    -email="$EMAIL" \
    -password="$PASSWORD"
