#!/bin/bash

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${YELLOW}===================================================="
echo -e "         Namada Update Script v1.0.0 > v1.1.1     "
echo -e "====================================================${NC}"

if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}This script must be run as root. Please use sudo or log in as root.${NC}"
    exit 1
fi
echo -e "${YELLOW}Checking if curl is installed...${NC}"
if ! command -v curl &> /dev/null; then
    echo -e "${RED}curl is not installed. Installing...${NC}"
    sudo apt install curl -y
fi

echo -e "${YELLOW}Updating all packages and dependencies...${NC}"
sudo apt update && sudo apt install make unzip clang pkg-config git-core libudev-dev libssl-dev build-essential libclang-12-dev protobuf-compiler git jq ncdu bsdmainutils htop lsof net-tools -y

echo -e "${YELLOW}Checking Namada version...${NC}"
NAMADA_VERSION=$(namada -V | awk '{print $2}')
if [[ "$NAMADA_VERSION" != "v1.0.0" ]]; then
    echo -e "${RED}Namada version is v1.0.0: $NAMADA_VERSION${NC}"
    exit 1
fi

echo -e "${YELLOW}Identifying Namada node port...${NC}"
CONFIG_PATH="$HOME/.namada/config/config.toml"
if [[ -f "$CONFIG_PATH" ]]; then
    NAMADA_PORT=$(grep -Po '(?<=laddr = "tcp://0.0.0.0:)[0-9]+' "$CONFIG_PATH")
else
    NAMADA_PORT=26657
fi

echo -e "${GREEN}Detected Namada RPC port: $NAMADA_PORT${NC}"

echo -e "${YELLOW}Checking Namada version...${NC}"
NAMADA_VERSION=$(namada -V | awk '{print $2}')
if [[ "$NAMADA_VERSION" != "v1.0.0" ]]; then
    echo -e "${RED}Namada version is incorrect: $NAMADA_VERSION. Exiting.${NC}"
    exit 1
fi

echo -e "${YELLOW}Checking Chain ID...${NC}"
CHAIN_ID="namada.5f5de2dd1b88cba30586420"
echo -e "Expected Chain ID: $CHAIN_ID"

NODE_STATUS_JSON=$(curl -s http://localhost:26657/status)
if [[ -z "$NODE_STATUS_JSON" || "$NODE_STATUS_JSON" == "null" ]]; then
    echo -e "${RED}Failed to fetch node status. Ensure Namada is running and port 26657 is accessible. Exiting.${NC}"
    exit 1
fi

CHAIN_ID_CHECK=$(echo "$NODE_STATUS_JSON" | jq -r '.result.node_info.network')
if [[ -z "$CHAIN_ID_CHECK" || "$CHAIN_ID_CHECK" == "null" ]]; then
    echo -e "${RED}Could not determine Chain ID from the response. Exiting.${NC}"
    exit 1
fi

echo -e "Detected Chain ID: $CHAIN_ID_CHECK"

if [[ "$CHAIN_ID_CHECK" != "$CHAIN_ID" ]]; then
    echo -e "${RED}Chain ID mismatch! Expected: $CHAIN_ID, Found: $CHAIN_ID_CHECK. Exiting.${NC}"
    exit 1
fi

COMETBFT_VERSION="v$(cometbft version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
echo -e "${YELLOW}Checking cometbft version: $COMETBFT_VERSION${NC}"
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
    echo -e "${GREEN}CometBFT updated to v0.37.15!${NC}"
else
    echo -e "${GREEN}CometBFT is already up-to-date. Skipping update.${NC}"
fi

echo -e "${YELLOW}Installing Rust...${NC}"
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"
rustup update
rustc --version
cargo --version

echo -e "${YELLOW}Updating Namada to v1.1.1...${NC}"
cd $HOME
rm -rf namada
git clone https://github.com/anoma/namada.git
cd namada
git fetch --all
git checkout tags/v1.1.1

echo -e "${YELLOW}Building Namada binaries...${NC}"
make build

NAMADA_BIN_PATH=$(which namada)
NAMADA_BIN_DIR=$(dirname "$NAMADA_BIN_PATH")
cp -rfa ./target/release/namada* "$NAMADA_BIN_DIR/"
source $HOME/.bash_profile

echo -e "${YELLOW}Testing Namada binary...${NC}"
NEW_NAMADA_VERSION=$(namada --version)
if [[ "$NEW_NAMADA_VERSION" == *"v1.1.1"* ]]; then
    echo -e "${GREEN}Namada successfully updated to v1.1.1!${NC}"
else
    echo -e "${RED}Namada update failed. Restarting from the beginning.${NC}"
    exit 1
fi

echo -e "${YELLOW}Restarting Namada node...${NC}"
sudo systemctl stop namadad
sudo systemctl start namadad

echo -e "${YELLOW}Checking if the node is syncing blocks...${NC}"
BLOCK_HEIGHT_START=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
BLOCK_INCREASING=false

for i in {1..3}; do
    sleep 5
    BLOCK_HEIGHT_CURRENT=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
    if [[ "$BLOCK_HEIGHT_CURRENT" -gt "$BLOCK_HEIGHT_START" ]]; then
        BLOCK_INCREASING=true
        BLOCK_HEIGHT_START=$BLOCK_HEIGHT_CURRENT
        echo -e "${YELLOW}Block height increased to: $BLOCK_HEIGHT_CURRENT${NC}"
    fi

done

if $BLOCK_INCREASING; then
    echo -e "${GREEN}Node is successfully syncing blocks.${NC}"
else
    echo -e "${RED}Node is not syncing blocks properly. Please check your setup.${NC}"
    exit 1
fi

echo -e "${YELLOW}========================================================="
echo -e " 🔍 Checking node status..."
echo -e "=========================================================${NC}"
NODE_STATUS=$(curl -s http://localhost:26657/status | jq -r '.result.sync_info.catching_up')
if [[ "$NODE_STATUS" == "false" ]]; then
    echo -e "${GREEN}✅ Node is successfully running on the mainnet v1.1.1 ✅${NC}"
    echo -e "${GREEN}✅ CometBFT is at v0.37.15 ✅${NC}"
else
    echo -e "${RED}Node is still catching up. Allow more time to sync.${NC}"
fi