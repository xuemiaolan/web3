#!/bin/bash

API_KEY="aptoslabs_UL361e67kqn_6D1nKb69k4DjE6KHVeUeYcQN5LoLZuPod"

sudo curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs yq
sudo npm install -g npm@11.6.2
sudo curl -fsSL "https://aptos.dev/scripts/install_cli.sh" | sh
sudo npm i -g @shelby-protocol/cli
source ~/.profile

shelby init --setup-default
yq --yaml-output -i ".contexts.shelbynet.api_key = \"$API_KEY\"" ~/.shelby/config.yaml

PK=$(yq -r '.accounts[] | .private_key' ~/.shelby/config.yaml)
ACC=$(yq -r '.accounts | keys[]' ~/.shelby/config.yaml)

aptos init --profile shelby-$ACC --assume-yes --private-key $PK --network custom \
  --rest-url https://api.shelbynet.aptoslabs.com --faucet-url https://faucet.shelbynet.shelby.xyz/

for i in {1..10}; do
  aptos account fund-with-faucet --profile shelby-$ACC --amount 10000000000000000000
done

shelby account balance

echo ""
echo "To receive shelbyUSD, please manually run:"
echo "shelby faucet --no-open"

