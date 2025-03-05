#!/bin/bash

# **Namada Update Script v1.1.1 > v1.1.2**
# Last Updated: March 5, 2025
# This script safely updates Namada to v1.1.2 without halting the node.
# Powered by papadritta


YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

LOG_FILE="/var/log/namada_update.log"
sudo touch $LOG_FILE
sudo chmod 644 $LOG_FILE
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${YELLOW}===================================================="
echo -e "         Namada Update Script v1.1.1 > v1.1.2     "
echo -e "====================================================${NC}"

# Function to handle rollback in case of failure
rollback() {
    echo -e "${RED}Rolling back to the previous version...${NC}"
    if [[ -f /root/namada_${NAMADA_VERSION}_backup ]]; then
        sudo mv /root/namada_${NAMADA_VERSION}_backup /usr/local/bin/namada
        echo -e "${GREEN}Rollback successful. Restarting Namada service...${NC}"
        sudo systemctl restart namadad
        exit 1
    else
        echo -e "${RED}Backup not found! Manual intervention required.${NC}"
        exit 1
    fi
}

# Function to handle errors
error_handler() {
    echo -e "${RED}An error occurred during the update process.${NC}"
    echo -e "${YELLOW}Select an option:${NC}"
    echo -e "1) Restart the installation"
    echo -e "2) Rollback to the previous version"
    read -p "Enter choice [1-2]: " choice
    case "$choice" in
        1) echo -e "${GREEN}Restarting installation...${NC}"; exec "$0" ;;
        2) rollback ;;
        *) echo -e "${RED}Invalid choice. Exiting.${NC}"; exit 1 ;;
    esac
}

# Trap errors and execute error_handler
trap error_handler ERR

# Function to ask user confirmation before proceeding
confirm_proceed() {
    while true; do
        echo -e "${YELLOW}Do you want to start the update process? (y/n)${NC}"
        read -r response
        case "$response" in
            [yY]) echo -e "${GREEN}Proceeding with the update...${NC}"; break ;;
            [nN]) echo -e "${RED}Update process aborted.${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid input. Please enter 'y' or 'n'.${NC}" ;;
        esac
    done
}

# Ask for confirmation before running the update
confirm_proceed

# Check if curl is installed, if not, install it
echo -e "${YELLOW}Checking if curl is installed...${NC}"
if ! command -v curl &> /dev/null; then
    echo -e "${RED}curl is not installed. Installing curl...${NC}"
    sudo apt update && sudo apt install curl -y
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Failed to install curl. Exiting...${NC}"
        exit 1
    else
        echo -e "${GREEN} curl installed successfully.${NC}"
    fi
else
    echo -e "${GREEN} curl is already installed.${NC}"
fi

# Check the script runs as root to avoid permission issues
echo -e "${YELLOW}Checking if script is run as root...${NC}"
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}This script must be run as root. Use sudo or log in as root.${NC}"
    exit 1
fi

# Update all system packages and dependencies
echo -e "${YELLOW}Updating system packages and dependencies...${NC}"
sudo apt update && sudo apt upgrade -y
sudo apt install --no-install-recommends make unzip clang pkg-config git-core libudev-dev libssl-dev build-essential libclang-18-dev protobuf-compiler git jq ncdu bsdmainutils htop lsof net-tools -y

# Check CometBFT version
if ! command -v cometbft &> /dev/null; then
    COMETBFT_VERSION=""
else
    COMETBFT_VERSION="v$(cometbft version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
fi
if [[ "$COMETBFT_VERSION" != "v0.37.15" ]]; then
    echo -e "${YELLOW}Updating CometBFT to v0.37.15...${NC}"
    cd /root
    sudo rm -rf cometbft_bin
    mkdir -p /root/cometbft_bin
    cd /root/cometbft_bin
    wget -O cometbft.tar.gz https://github.com/cometbft/cometbft/releases/download/v0.37.15/cometbft_0.37.15_linux_amd64.tar.gz
    tar xvf cometbft.tar.gz
    sudo chmod +x cometbft
    sudo mv ./cometbft /usr/local/bin/
fi

# Install or update Rust
echo -e "${YELLOW}Installing or updating Rust...${NC}"
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"
rustup update || { echo -e "${RED}Rust update failed! Exiting...${NC}"; exit 1; }
if ! command -v rustc &> /dev/null; then
    echo -e "${RED}Rust is not installed correctly. Exiting...${NC}"
    exit 1
fi
echo -e "Rust version: $(rustc --version)"
echo -e "Cargo version: $(cargo --version)"

# Backup existing Namada binary
NAMADA_VERSION=$(namada -V | awk '{print $2}')
echo -e "${YELLOW}Backing up Namada version $NAMADA_VERSION...${NC}"
cp -f $(which namada) /root/namada_${NAMADA_VERSION}_backup

# Build Namada from source
echo -e "${YELLOW}Building Namada v1.1.2 from source...${NC}"
cd /root
rm -rf /root/namada_src
mkdir -p /root/namada_src
cd /root/namada_src
git clone https://github.com/anoma/namada.git
cd namada
git fetch --all
git checkout tags/v1.1.2
make build -j$(nproc)

# Move binaries to /usr/local/bin and check
NAMADA_BIN_PATH=$(which namadan)
NAMADA_BIN_DIR=$(dirname "$NAMADA_BIN_PATH")
cp -rfa ./target/release/namada* "$NAMADA_BIN_DIR/"
source $HOME/.bash_profile
ls -lh /usr/local/bin/namada*

# Test the binary before Restart
INSTALLED_VERSION=$(namada --version | awk '{print $2}')
if [[ "$INSTALLED_VERSION" == "v1.1.2" ]]; then
    echo -e "${GREEN}✅ Namada v1.1.2 successfully installed.${NC}"
else
    echo -e "${RED}❌ Namada installation failed. Expected v1.1.2 but found $INSTALLED_VERSION.${NC}"
    rollback
fi

# Restart Namada service
sudo systemctl restart namadad
sleep 5
sudo systemctl status namadad --no-pager

# Check Node Block Production
echo -e "${YELLOW}Checking if the node is producing blocks...${NC}"
PREV_BLOCK_HEIGHT=$(curl -s localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
BLOCK_COUNT=0
MAX_ATTEMPTS=10
ATTEMPT=0
while [[ "$BLOCK_COUNT" -lt 3 && "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]]; do
    sleep 20
    ATTEMPT=$((ATTEMPT + 1))
    NEW_BLOCK_HEIGHT=$(curl -s localhost:26657/status | jq -r '.result.sync_info.latest_block_height')
    if [[ "$NEW_BLOCK_HEIGHT" -gt "$PREV_BLOCK_HEIGHT" ]]; then
        BLOCK_COUNT=$((BLOCK_COUNT + 1))
        PREV_BLOCK_HEIGHT=$NEW_BLOCK_HEIGHT
        echo -e "${GREEN}✅ Block $BLOCK_COUNT detected at height $NEW_BLOCK_HEIGHT.${NC}"
    else
        echo -e "${RED}❌ No new block detected, checking again...${NC}"
    fi
    if [[ "$BLOCK_COUNT" -eq 3 ]]; then
        echo -e "${GREEN}✅ Node is producing blocks normally.${NC}"
        break
    fi
done
if [[ "$BLOCK_COUNT" -lt 3 ]]; then
    echo -e "${RED}❌ Node did not produce 3 blocks within the timeout period.${NC}"
    echo "ALERT: Node did not sync within expected time. Check manually." >> $LOG_FILE
    rollback
fi

# Cleanup leftover build files
cd /root
rm -rf /root/cometbft_bin
rm -rf /root/namada_src

# Final confirmation message
echo -e "${GREEN}Namada has been successfully updated to v1.1.2.${NC}"
echo -e "${YELLOW}Please check the node status with 'namada status' command.${NC}"