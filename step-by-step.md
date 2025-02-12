# Namada Step-By-step Update  v1.0.0 > v1.1.1

###############################################################################
## 1. Steps before the Block reached `894000`:
###############################################################################

#### Updating all packages and dependencies
```bash
sudo apt update && sudo apt install make unzip clang pkg-config git-core libudev-dev libssl-dev build-essential libclang-18-dev protobuf-compiler git jq ncdu bsdmainutils htop lsof net-tools -y
```
#### Check CometBFT 
```bash 
cometbft version #must be v0.37.15
```
#### & If needed to Updating CometBFT to v0.37.15
```bash
cd $HOME
sudo rm -rf cometbft_bin
mkdir -p $HOME/cometbft_bin
cd $HOME/cometbft_bin
wget -O cometbft.tar.gz https://github.com/cometbft/cometbft/releases/download/v0.37.15/cometbft_0.37.15_linux_amd64.tar.gz
tar xvf cometbft.tar.gz
sudo chmod +x cometbft
sudo mv ./cometbft /usr/local/bin/
```
#### Update Rust
```bash
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"
rustup update
rustc --version
cargo --version
```
#### Make a backup
```bash
cp $(which namadan) $HOME/namadan_v1.0.0_backup
```
#### Build namada from source
```bash
cd $HOME
mkdir -p $HOME/namada_src
cd $HOME/namada_src
git clone https://github.com/anoma/namada.git
cd namada
git fetch --all
git checkout tags/v1.1.1
make build
```
#### Set the ledger to run until block height 894000 then halt
```bash
namadan -V # Must be v1.0.0 before block 894000
export BLOCK_HEIGHT=894000
namadan ledger run-until --block-height $BLOCK_HEIGHT --halt
```
#### Modify systemd service to prevent auto-restart before update
```bash
sed -i 's/^Restart=.*/Restart=no/' /etc/systemd/system/namadad.service
systemctl daemon-reload
```

#### You can Monitor the Current block
```bash
curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height'
```
!!! WARNING !!! Your node will halt after committing block 893999, not 894000.

###############################################################################
## 2. Steps After the Block reached 894000 - 1:
###############################################################################

#### Stop the node before upgrade
```bash
sudo systemctl stop namadad
```
#### Move binaries
```bash
cd $HOME
cd $HOME/namada_src/namada
sudo mv target/release/namada* /usr/local/bin/
```
#### Check the node version
```bash
namada -V #should be v1.1.1
```
#### #### Run ledger to check if node is catching up
```bash
namadan ledger run
```
!!! WARNING!!! Your node may not start producing blocks immediately. 
Block production resumes only after 2/3 of the network completes the upgrade.

###############################################################################
## 3. Steps After the Node start producing the blocks:
###############################################################################
#### Revert systemd service
```bash
sed -i 's/^Restart=no/Restart=always/' /etc/systemd/system/namadad.service
systemctl daemon-reload
```
#### Start Service
```bash
sudo systemctl start namadad
```
#### Check the node status
```bash
curl -s http://localhost:26657/status | jq -r '.result.sync_info.catching_up'
```
#### Monitor logs
```bash
sudo journalctl -u namadad -f -o cat
```
#### In case of fail
```bash
sudo systemctl stop namadad
sudo systemctl disable namadad
sudo systemctl enable namadad
sudo systemctl restart namadad
sudo journalctl -u namadad -f -o cat
```
#### Clean up the leftovers
```bash
rm -rf $HOME/cometbft_bin
rm -rf $HOME/namada_src
```
