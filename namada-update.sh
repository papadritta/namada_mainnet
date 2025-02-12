#!/bin/bash

# Namada Mainnet Update Script v1.0.0 > v1.1.1
# Last Updated: Feb 12, 2025
# This script is a safe update process to avoiding early restarts or slashing risks.
# Halt the ledger at block height 894000, update Namada to v1.1.1, and restart the node.

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${YELLOW}===================================================="
echo -e "       Namada Mainnet Update Script v1.0.0 > v1.1.1     "
echo -e "====================================================${NC}"

# Check if the script runs as root to avoid permission issues
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}This script must be run as root. Use sudo or log in as root.${NC}"
    exit 1
fi

# Check for curl and install if missing
if ! command -v curl &> /dev/null; then
    echo -e "${RED}curl is not installed. Installing...${NC}"
    sudo apt install curl -y
fi

# Update system packages
sudo apt update && sudo apt install make unzip clang pkg-config git-core libudev-dev libssl-dev build-essential libclang-12-dev protobuf-compiler git jq ncdu bsdmainutils htop lsof net-tools -y

# Check if Namada version is v1.0.0 before proceeding
NAMADA_VERSION=$(namada -V | awk '{print $2}')
if [[ "$NAMADA_VERSION" != "v1.0.0" ]]; then
    echo -e "${RED}Namada version mismatch! Expected: v1.0.0, Found: $NAMADA_VERSION. Exiting.${NC}"
    exit 1
fi

# Detect Namada port from config.toml
CONFIG_PATH="$HOME/.namada/config/config.toml"
NAMADA_PORT=26657  # Default
if [[ -f "$CONFIG_PATH" ]]; then
    NAMADA_PORT=$(grep -Po '(?<=laddr = "tcp://0.0.0.0:)[0-9]+' "$CONFIG_PATH")
fi

# Ensure CometBFT is up-to-date
COMETBFT_VERSION="v$(cometbft version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
if [[ "$COMETBFT_VERSION" != "v0.37.15" ]]; then
    echo -e "${YELLOW}Updating CometBFT to v0.37.15...${NC}"
    cd $HOME
    sudo rm -rf cometbft_bin
    mkdir -p $HOME/cometbft_bin
    cd $HOME/cometbft_bin
    wget -O cometbft.tar.gz https://github.com/cometbft/cometbft/releases/download/v0.37.15/cometbft_0.37.15_linux_amd64.tar.gz
    tar xvf cometbft.tar.gz
    sudo chmod +x cometbft
    sudo mv ./cometbft /usr/local/bin/
fi

# Install or update Rust
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"
rustup update

# Backup Namada v1.0.0 in case of failure
cp $(which namadan) $HOME/namadan_v1.0.0_backup

# Build Namada v1.1.1 from source
cd $HOME
mkdir -p $HOME/namada_src
cd $HOME/namada_src
git clone https://github.com/anoma/namada.git
cd namada
git fetch --all
git checkout tags/v1.1.1
make build

# Verify built binaries before moving them
[[ -f /root/namada_src/namada/target/release/namada ]] && ls -lah /root/namada_src/namada/target/release/ && /root/namada_src/namada/target/release/namada -V

# Modify systemd service for safe halt at block 894000
sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/local/bin/namadan ledger run-until --block-height 894000 --halt|' /etc/systemd/system/namadad.service
sudo sed -i 's|^Restart=.*|Restart=on-failure|' /etc/systemd/system/namadad.service
sudo systemctl daemon-reload
#sudo systemctl restart namadad

# Wait until block 894000 before proceeding
while true; do
    CURRENT_HEIGHT=$(curl -s http://localhost:$NAMADA_PORT/status | jq -r '.result.sync_info.latest_block_height')
    echo -e "${YELLOW}Current block height: $CURRENT_HEIGHT${NC}"
    if [[ "$CURRENT_HEIGHT" -ge "894000" ]]; then
        echo -e "${GREEN}Target block reached! Proceeding with upgrade.${NC}"
        break
    fi
    sleep 60
done

# Stop Namada before upgrading
sudo systemctl stop namadad

# Move new binaries to /usr/local/bin
sudo mv $HOME/namada_src/namada/target/release/namada* /usr/local/bin/

# Verify new Namada version
NEW_NAMADA_VERSION=$(namada -V | awk '{print $2}')
if [[ "$NEW_NAMADA_VERSION" != "v1.1.1" ]]; then
    echo -e "${RED}Version check failed! Namada is still at $NEW_NAMADA_VERSION. Exiting.${NC}"
    exit 1
fi

# Start the Namada service
sudo systemctl start namadad

# Wait until the node starts syncing
echo -e "${YELLOW}Waiting for the node to start syncing...${NC}"
BLOCK_HEIGHT_START=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
SYNC_STARTED=false

for i in {1..10}; do
    sleep 60
    BLOCK_HEIGHT_CURRENT=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
    if [[ "$BLOCK_HEIGHT_CURRENT" -gt "$BLOCK_HEIGHT_START" ]]; then
        SYNC_STARTED=true
        echo -e "${GREEN}Node is syncing! Block height increased to: $BLOCK_HEIGHT_CURRENT${NC}"
        break
    fi
done

if ! $SYNC_STARTED; then
    echo -e "${RED}❌ Node is not syncing! Please check logs.${NC}"
    exit 1
fi

# Restore systemd settings to allow automatic restarts
sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/local/bin/namadan ledger run|' /etc/systemd/system/namadad.service
sudo sed -i 's|^Restart=.*|Restart=always|' /etc/systemd/system/namadad.service
sudo systemctl daemon-reload
sudo systemctl restart namadad

# Verify syncing status
NODE_STATUS=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.catching_up')
if [[ "$NODE_STATUS" == "false" ]]; then
    echo -e "${GREEN}✅ Node successfully running on Namada v1.1.1 ✅${NC}"
else
    echo -e "${RED}Node is still catching up. Monitor logs for progress.${NC}"
fi

# Cleanup
rm -rf $HOME/cometbft_bin
rm -rf $HOME/namada_src
