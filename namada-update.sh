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
echo -e "         Namada Update Script v1.0.0 > v1.1.1     "
echo -e "====================================================${NC}"

# Check the script runs as root to avoid permission issues
echo -e "${YELLOW}Checking if script is run as root...${NC}"
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}This script must be run as root. Use sudo or log in as root.${NC}"
    exit 1
fi

# Update system packages and install dependencies
echo -e "${YELLOW}Updating system packages...${NC}"
sudo apt update && sudo apt install make unzip clang pkg-config git-core libudev-dev libssl-dev build-essential libclang-18-dev protobuf-compiler git jq ncdu bsdmainutils htop lsof net-tools -y

# Check CometBFT version and update if necessary
echo -e "${YELLOW}Checking CometBFT version...${NC}"
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
echo -e "${YELLOW}Installing or updating Rust...${NC}"
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"
rustup update

# Check Namada version before proceeding
echo -e "${YELLOW}Checking Namada version before proceeding...${NC}"
NAMADA_VERSION=$(namada -V | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+')
if [[ -z "$NAMADA_VERSION" ]]; then
    echo -e "${RED}❌ Error: Unable to determine Namada version. Please check installation.${NC}"
    exit 1
elif [[ "$NAMADA_VERSION" != "v1.0.0" ]]; then
    echo -e "${RED}❌ Namada version mismatch! Expected: v1.0.0, Found: $NAMADA_VERSION.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ Namada version is correct: $NAMADA_VERSION.${NC}"
fi

# Backup Namada v1.0.0 in case of failure
echo -e "${YELLOW}Backing up Namada v1.0.0 in case of failure...${NC}"
cp $(which namadan) $HOME/namadan_v1.0.0_backup

# Build Namada v1.1.1 from source
echo -e "${YELLOW}Building Namada v1.1.1 from source...${NC}"
cd $HOME
mkdir -p $HOME/namada_src
cd $HOME/namada_src
git clone https://github.com/anoma/namada.git
cd namada
git fetch --all
git checkout tags/v1.1.1
make build

# Verify built binaries before moving them
echo -e "${YELLOW}Verifying built binaries before moving them...${NC}"
[[ -f /root/namada_src/namada/target/release/namada ]] && ls -lah /root/namada_src/namada/target/release/ && /root/namada_src/namada/target/release/namada -V

# Modify systemd service for safe halt at block 894000
echo -e "${YELLOW}Modifying systemd service for safe halt at block 894000...${NC}"
sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/local/bin/namadan ledger run-until --block-height 894000 --halt|' /etc/systemd/system/namadad.service
sudo sed -i 's|^Restart=.*|Restart=on-failure|' /etc/systemd/system/namadad.service
sudo systemctl daemon-reload && sudo systemctl restart namadad

# Wait until block 894000 before proceeding with upgrade
echo -e "${YELLOW}Waiting until block 894000 before proceeding...${NC}"
while true; do
    CURRENT_HEIGHT=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
    echo -e "${YELLOW}Current block height: $CURRENT_HEIGHT${NC}"
    if [[ "$CURRENT_HEIGHT" -ge "894000" ]]; then
        echo -e "${GREEN}Target block reached! Proceeding with upgrade.${NC}"
        break
    fi
    sleep 60
done

# Stop Namada before upgrading when block 894000 is reached
echo -e "${YELLOW}Stopping Namada before upgrading...${NC}"
sudo systemctl stop namadad

# Move new binaries to /usr/local/bin
echo -e "${YELLOW}Moving new binaries to /usr/local/bin...${NC}"
sudo mv $HOME/namada_src/namada/target/release/namada* /usr/local/bin/

# Verify new Namada version
echo -e "${YELLOW}Verifying new Namada version...${NC}"
NEW_NAMADA_VERSION=$(namada -V | awk '{print $2}')
if [[ "$NEW_NAMADA_VERSION" != "v1.1.1" ]]; then
    echo -e "${RED}Version check failed! Namada is still at $NEW_NAMADA_VERSION. Exiting.${NC}"
    exit 1
fi

# Need to adjust to run new version as systemd service
echo -e "${YELLOW}Adjusting systemd service to run new version...${NC}"
sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/local/bin/namadan ledger run|' /etc/systemd/system/namadad.service

# Start a new version of Namada and wait for sync
echo -e "${YELLOW}Starting Namada service and waiting for sync...${NC}"
sudo systemctl daemon-reload && sudo systemctl restart namadad
sleep 10

# Check if node is syncing and producing blocks, make a loop to check every 60 seconds
echo -e "${YELLOW}Checking if node is syncing and producing blocks...${NC}"
BLOCK_COUNT=0
while true; do
    SYNC_STATUS=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.catching_up')
    CURRENT_HEIGHT=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
    LATEST_BLOCK_TIME=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_time')
    PEERS=$(curl -s http://localhost:26657/net_info | jq -r '.result.n_peers')
    
    echo -e "${YELLOW}Peers connected: $PEERS${NC}"
    echo -e "${YELLOW}Latest block height: $CURRENT_HEIGHT | Last block time: $LATEST_BLOCK_TIME${NC}"
    
    if [[ "$SYNC_STATUS" == "false" ]]; then
        BLOCK_COUNT=$((BLOCK_COUNT+1))
        echo -e "${GREEN}✅ Node is synced and producing blocks. Block count since restart: $BLOCK_COUNT.${NC}"
    else
        BLOCK_COUNT=0
        echo -e "${YELLOW}Node is still catching up. Checking again in 60 seconds...${NC}"
    fi
    
    if [[ "$BLOCK_COUNT" -ge 5 ]]; then
        echo -e "${GREEN}✅ Node has produced 5 blocks. Upgrade process is complete.${NC}"
        break
    fi
    
    sleep 60
done

# Restore systemd settings to allow automatic restarts
echo -e "${YELLOW}Restoring systemd settings to allow automatic restarts...${NC}"
sudo sed -i 's|^Restart=.*|Restart=always|' /etc/systemd/system/namadad.service
sudo systemctl daemon-reload && sudo systemctl restart namadad

# Clean up temporary files
echo -e "${YELLOW}Cleaning up temporary files...${NC}"
rm -rf $HOME/cometbft_bin
rm -rf $HOME/namada_src

# Display final status message
echo -e "${GREEN}Namada has been successfully updated to v1.1.1.${NC}"
echo -e "${YELLOW}Please check the node status with 'namada status' command.${NC}"

