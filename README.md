# Namada Mainnet Update Script from v1.0.0 to v1.1.1
![Current Block](https://img.shields.io/badge/Current_Block-879395-blue)
![Blocks Left](https://img.shields.io/badge/Blocks_Left-14605-blue)
![Target Block](https://img.shields.io/badge/Target_Block-894000-blue)

## Description
🔗 [Namada v1.1.1 Release](https://github.com/anoma/namada/releases/tag/v1.1.1)
**Expected update block height: [894000](https://namada.valopers.com/blocks/894000)**
This Bash script automates the update of Namada from **v1.0.0 to v1.1.1**. It checks all dependencies are installed, verifies the correct **Chain ID** `namada.5f5de2dd1b88cba30586420`, checks and updates **CometBFT** to **v0.37.15**, builds the latest **Namada binaries**, and restarts the node and syncs it properly.

## Features
- ✅ Checks if the script is run as root
- ✅ Installs & updates required dependencies
- ✅ Detects and updates **CometBFT** only if necessary
- ✅ Clones and builds the latest **Namada v1.1.1** from source
- ✅ Automatically restarts the node and verifies block synchronization
- ✅ Provides clear status messages for troubleshooting


## Usage: AUTO :point_down: or [Step-by-step](/step-by-step.md)
Run the following command to download and execute the script:
```bash
curl -s https://raw.githubusercontent.com/papadritta/namada_mainnet/main/namada-update.sh | sudo bash -e
```
## What Next After Update? > Restore systemd service to allow automatic restarts
>#### !!! WARNING: CHANGE IT ONLY AFTER THE HALT IS OVER AND CHAIN IS RUNNING
```bash
sed -i 's/^Restart=no/Restart=always/' /etc/systemd/system/namadad.service
systemctl daemon-reload
systemctl restart namadad
```
## Troubleshooting
### If the script exits or fails:
1. **Check the error message** displayed in the terminal.
2. **Verify Namada is running** using:
```bash
sudo systemctl status namadad
```
3. **Check logs for more details:**
```bash
sudo journalctl -u namadad -f -o cat
```
4. **Check the correct ports are open**:
```bash
sudo netstat -tulnp | grep namada
```
5. **Retry running the script** if an intermittent error occurs.

### If the node is not syncing blocks:
- Run the following to check block height manually:
```bash
curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height'
```
- If blocks are not increasing, restart Namada:
```bash
sudo systemctl restart namadad
```
- If the issue persists, check network connectivity add peers & seeds and re-run the update script.

## Support
For any issues, open an issue on the repository or check the [Namada documentation.](https://docs.namada.net)

