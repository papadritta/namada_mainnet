# Namada Mainnet Update Script from v1.1.1 to v1.1.2
![Current Block](https://img.shields.io/badge/Current_Block-861342-blue)

## Description
🔗 [Namada v1.1.1 Release](https://github.com/anoma/namada/releases/tag/v1.1.2)

This Bash script automates the update of Namada from **v1.1.1 to v1.1.2**. It checks all dependencies are installed, verifies the correct **Chain ID** `namada.5f5de2dd1b88cba30586420`, **Service Name** `namadad.service`,checks and updates **CometBFT** to **v0.37.15**, builds the latest **Namada binaries**, and restarts the node and syncs it properly.

## Features
- ✅ Checks if the script is run as root
- ✅ Installs & updates required dependencies
- ✅ Detects and updates **CometBFT** only if necessary
- ✅ Clones and builds the latest **Namada v1.1.2** from source
- ✅ Rollback Mechanism: If an update fails, restores the previous version
- ✅ Enhanced Block Production Check: Ensures the node is producing new blocks
- ✅ Logs all operations to `/var/log/namada_update.log`
- ✅ Provides clear status messages for troubleshooting

## AUTO Update Script :point_down:
> 🚧 **Testing Mode Active**: Installation is currently disabled for Testing & verification. 
Run the following command to download and execute the script:
```bash
curl -s https://raw.githubusercontent.com/papadritta/namada_mainnet/main/box/update_1.1.2.sh | sudo bash -e
```
> **Tested on**: Ubuntu 24.04.1 LTS (GNU/Linux 6.8.0-41-generic x86_64)

## 🆘 Troubleshooting

### If the script exits or fails:

1. **Check the log file:** 
```bash
cat /var/log/namada_update.log
```
2. **Verify Namada is running:**
```bash
sudo systemctl status namadad
```
3. **Check live logs:**
```bash
sudo journalctl -u namadad -f -o cat
```
4. **Check correct ports are open:**
```bash
sudo netstat -tulnp | grep namada
```
5. **Retry running the script** if an intermittent error occurs.

###  If the node is not syncing blocks:

6. **Check block height manually:**
```bash
curl -s http://localhost:26657/status | jq -r '.result.sync_info.latest_block_height'
```
7. **Restart Namada:**
```bash
sudo systemctl restart namadad
```
8. **Perform a ledger rollback if stuck:**
```bash
sudo systemctl stop namadad && namadan node ledger rollback && sudo systemctl start namadad
```
9. **If the issue persists, check network connectivity add peers & seeds and re-run the script.**
```bash
curl -s http://localhost:26657/net_info | jq -r '.result.n_peers'
```
```bash
curl -s http://localhost:26657/net_info | jq -r '.result.peers[] | {moniker: .node_info.moniker, remote_ip: .remote_ip}'
```
## Support
For any issues, open an issue on the repository or check the [Namada documentation.](https://docs.namada.net)

