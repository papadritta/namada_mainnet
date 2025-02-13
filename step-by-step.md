# Namada Step-By-step Update  v1.0.0 > v1.1.1
![Current Block](https://img.shields.io/badge/Current_Block-892874-blue)
![Blocks Left](https://img.shields.io/badge/Blocks_Left-1126-blue)
![Target Block](https://img.shields.io/badge/Target_Block-894000-blue)

###############################################################################
## 1. Steps before the Block reached `894000`:
###############################################################################
>**Tested on**: Ubuntu 24.04.1 LTS (GNU/Linux 6.8.0-41-generic x86_64)

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
#### Check the version
```bash
namadan -V # Must be v1.0.0 before block 894000
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
#### Check binaries on the place & node version
```bash
[[ -f /root/namada_src/namada/target/release/namada ]] && ls -lah $HOME/namada_src/namada/target/release/
[[ -f /root/namada_src/namada/target/release/namada ]] && /root/namada_src/namada/target/release/namada -V
```
#### Check the Current block & you can monitor it later
```bash
curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height'
```
#### Setup the systemd service and wait the halt
```bash
sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/local/bin/namadan ledger run-until --block-height 894000 --halt|' /etc/systemd/system/namadad.service && \
sudo sed -i 's|^Restart=.*|Restart=on-failure|' /etc/systemd/system/namadad.service && \
sudo systemctl daemon-reload && sudo systemctl restart namadad
```
#### Monitor logs
```bash
sudo journalctl -u namadad -f -o cat
```
!!! WARNING !!! Your node will halt after committing block 893999, not 894000.
DO NOT restart it until you've completed the upgrade!

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
#### Check the version again
```bash
namada -V #should be v1.1.1
```
#### After Upgrade, Check Node is Running Before Restarting Systemd
```bash
namadan ledger run
```

!!! WARNING!!! Wait! Your node may not start producing blocks immediately. 
Block production resumes only after 2/3 of the network completes the upgrade.

###############################################################################
## 3. Steps After the Node start producing the blocks:
###############################################################################

#### Verify that nothing is running on the background
```bash
ps aux | grep namada
```
> if **YES** kill the process
```bash
pkill -9 namada
```

#### Revert systemd service & restart
```bash
sudo sed -i 's|^ExecStart=.*|ExecStart=/usr/local/bin/namadan ledger run|' /etc/systemd/system/namadad.service && \
sudo sed -i 's|^Restart=.*|Restart=always|' /etc/systemd/system/namadad.service && \
sudo systemctl daemon-reload && sudo systemctl restart namadad
```

#### Check the node status
```bash
curl -s http://localhost:26657/status | jq -r '.result.sync_info.catching_up'
```
#### Monitor logs
```bash
sudo journalctl -u namadad -f -o cat
```
!!! WARNING!!! Wait! Your node may not start producing blocks immediately.

#### In case of fail
```bash
sudo systemctl restart namadad
```
>or 
```bash
sudo systemctl stop namadad
sudo systemctl disable namadad
sudo systemctl enable namadad
sudo systemctl start namadad
sudo journalctl -u namadad -f -o cat
```
#### Clean up the leftovers
```bash
rm -rf $HOME/cometbft_bin
rm -rf $HOME/namada_src
```
