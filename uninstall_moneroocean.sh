#!/bin/bash
# Uninstall MoneroOcean miner (XMRig)

echo "[*] Stopping and disabling systemd service if it exists..."
if systemctl list-unit-files | grep -q moneroocean_miner.service; then
    sudo systemctl stop moneroocean_miner.service
    sudo systemctl disable moneroocean_miner.service
    sudo rm -f /etc/systemd/system/moneroocean_miner.service
    sudo systemctl daemon-reload
    echo "[+] Service removed."
else
    echo "[-] No systemd service found."
fi

echo "[*] Killing any running xmrig processes..."
sudo killall -q xmrig 2>/dev/null

echo "[*] Removing cron jobs..."
crontab -l | grep -v 'xmrig\|moneroocean' | crontab -
sudo crontab -l | grep -v 'xmrig\|moneroocean' | sudo crontab -

echo "[*] Removing miner directories..."
rm -rf ~/moneroocean
sudo rm -rf /root/moneroocean

echo "[*] Removing xmrig binary if installed globally..."
sudo rm -f /usr/local/bin/xmrig

echo "[*] Cleaning up logs..."
sudo rm -f /var/log/moneroocean_miner.log

echo "[*] Done. You may want to reboot to ensure all processes are cleared."
