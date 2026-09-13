# ⚡ Freaky's Bash Alias Cheat Sheet
## 📁 Navigation

| Alias  | Command    | Description                |
| ------ | ---------- | -------------------------- |
| `..`   | `cd ..`    | Go up one directory        |
| `...`  | `cd ../..` | Go up two directories      |
| `ll`   | `ls -lah`  | Detailed directory listing |
| `home` | `cd ~`     | Go to home directory       |
| `cwd`  | `pwd`      | Show current directory     |
| `clr`  | `clear`    | Clear terminal             |
| `cls`  | `clear`    | Clear terminal             |

## 🖥️ System

| Alias      | Command                     | Description                    |
| ---------- | --------------------------- | ------------------------------ |
| `kernel`   | `uname -a`                  | Show kernel/system information |
| `os`       | `cat /etc/os-release`       | Show OS information            |
| `load`     | `uptime`                    | Show uptime and system load    |
| `mem`      | `free -h`                   | Show memory usage              |
| `reboot`   | `sudo reboot`               | Reboot the system              |
| `shutdown` | `sudo shutdown -h now`      | Shut down the system           |
| `psall`    | `ps aux`                    | List all running processes     |
| `psg`      | `ps aux \| grep`            | Search running processes       |
| `pgrep`    | `pgrep -af`                 | Search processes               |
| `top`      | `htop`                      | Interactive process monitor    |
| `dmesg`    | `sudo dmesg --color=always` | Show kernel messages           |
| `pci`      | `lspci`                     | List PCI devices               |
| `usb`      | `lsusb`                     | List USB devices               |

## 📦 APT / Packages

| Alias       | Command                                        | Description           |
| ----------- | ---------------------------------------------- | --------------------- |
| `apt`       | `sudo apt`                                     | Run APT with sudo     |
| `update`    | `sudo apt update && sudo apt upgrade -y`       | Update system         |
| `install`   | `sudo apt install`                             | Install a package     |
| `aptsearch` | `apt search`                                   | Search packages       |
| `clean`     | `sudo apt autoremove -y && sudo apt autoclean` | Clean unused packages |


## 💾 Storage

| Alias      | Command                                 | Description                    |
| ---------- | --------------------------------------- | ------------------------------ |
| `df`       | `df -h`                                 | Show disk usage                |
| `disk`     | `df -h`                                 | Show disk usage                |
| `disks`    | `lsblk -f`                              | List disks and filesystems     |
| `du`       | `du -sh *`                              | Show directory sizes           |
| `bigfiles` | `sudo du -ah / \| sort -rh \| head -20` | Find largest files/directories |
| `mounts`   | `mount \| column -t`                    | Show mounted filesystems       |

## 🌐 Network

| Alias         | Command                    | Description                      |
| ------------- | -------------------------- | -------------------------------- |
| `lip`         | `hostname -I`              | Show local IP addresses          |
| `wip`         | `curl icanhazip.com`       | Show public IP                   |
| `ports`       | `sudo ss -tulpn`           | Show listening ports             |
| `openports`   | `sudo ss -lntup`           | Show open/listening ports        |
| `conns`       | `ss -tunap`                | Show network connections         |
| `established` | `ss -tn state established` | Show established TCP connections |
| `ipa`         | `ip addr`                  | Show network interfaces          |
| `route`       | `ip route`                 | Show routing table               |
| `pingg`       | `ping -c 4 8.8.8.8`        | Ping Google DNS                  |
| `pingc`       | `ping -c 4 1.1.1.1`        | Ping Cloudflare DNS              |
| `dns`         | `dig`                      | DNS lookup                       |
| `digg`        | `dig`                      | DNS lookup                       |
| `headers`     | `curl -I`                  | Show HTTP headers                |
| `trace`       | `traceroute`               | Trace network route              |

## 🔐 SSH

| Alias       | Command                                  | Description                 |
| ----------- | ---------------------------------------- | --------------------------- |
| `sshlist`   | `ssh-add -l`                             | List loaded SSH keys        |
| `ssha`      | `ssh-agent + ssh-add`                    | Start SSH agent and add key |
| `sshconfig` | `nano ~/.ssh/config`                     | Edit SSH config             |
| `sshperm`   | `chmod 700 ~/.ssh && chmod 600 ~/.ssh/*` | Fix SSH permissions         |
| `sshhosts`  | `cat ~/.ssh/known_hosts`                 | Show known SSH hosts        |

## ⚙️ Systemd
| Alias      | Command                                    | Description             |
| ---------- | ------------------------------------------ | ----------------------- |
| `services` | `systemctl --type=service --state=running` | List running services   |
| `failed`   | `systemctl --failed`                       | Show failed services    |
| `sstatus`  | `sudo systemctl status`                    | Service status          |
| `srestart` | `sudo systemctl restart`                   | Restart service         |
| `sstart`   | `sudo systemctl start`                     | Start service           |
| `sstop`    | `sudo systemctl stop`                      | Stop service            |
| `senable`  | `sudo systemctl enable`                    | Enable service at boot  |
| `sdisable` | `sudo systemctl disable`                   | Disable service at boot |
```bash
sstatus docker
srestart docker
sstart nginx
sstop nginx
```

## 📜 Logs / Journalctl
| Alias       | Command                         | Description              |
| ----------- | ------------------------------- | ------------------------ |
| `logs`      | `sudo journalctl -f`            | Follow live system logs  |
| `sjournal`  | `sudo journalctl -u`            | Show service logs        |
| `todaylogs` | `sudo journalctl --since today` | Today's logs             |
| `bootlogs`  | `sudo journalctl -b`            | Logs from current boot   |
| `klogs`     | `sudo journalctl -k`            | Kernel logs              |
| `errors`    | `sudo journalctl -p err -b`     | Errors from current boot |
```bash
sjournal docker
sjournal nginx
errors
todaylogs
```

## 🐳 Docker
| Alias      | Command               | Description                   |
| ---------- | --------------------- | ----------------------------- |
| `dps`      | `docker ps`           | Running containers            |
| `dpsa`     | `docker ps -a`        | All containers                |
| `dimg`     | `docker images`       | List images                   |
| `dlog`     | `docker logs -f`      | Follow container logs         |
| `dstats`   | `docker stats`        | Container resource usage      |
| `dtop`     | `docker top`          | Container processes           |
| `dstart`   | `docker start`        | Start container               |
| `dstop`    | `docker stop`         | Stop container                |
| `drestart` | `docker restart`      | Restart container             |
| `drm`      | `docker rm`           | Remove container              |
| `dockerdu` | `docker system df`    | Docker disk usage             |
| `dclean`   | `docker system prune` | Clean unused Docker resources |
```bash
dps
dlog nginx
drestart grafana
dstop container_name
```

## 🐳 Docker Compose

| Alias       | Command                                       | Description           |
| ----------- | --------------------------------------------- | --------------------- |
| `dcup`      | `docker compose up -d`                        | Start Compose stack   |
| `dcdown`    | `docker compose down`                         | Stop Compose stack    |
| `dcrestart` | `docker compose restart`                      | Restart stack         |
| `dcps`      | `docker compose ps`                           | Show stack containers |
| `dclog`     | `docker compose logs -f`                      | Follow stack logs     |
| `dcpull`    | `docker compose pull`                         | Pull latest images    |
| `dcupdate`  | `docker compose pull && docker compose up -d` | Update stack          |
| `dcrebuild` | `docker compose up -d --build`                | Rebuild and start     |

## 🛠️ Tools / Utilities

| Alias          | Command                 | Description               |
| -------------- | ----------------------- | ------------------------- |
| `cat`          | `batcat`                | Enhanced `cat`            |
| `wt`           | `curl wttr.in`          | Terminal weather          |
| `speed`        | `curl ... \| python3 -` | Internet speed test       |
| `aliases`      | `nano ~/.bash_aliases`  | Edit aliases              |
| `reload`       | `source ~/.bashrc`      | Reload Bash configuration |
| `aliases-list` | `alias`                 | List all aliases          |
| `hist`         | `history`               | Show command history      |
| `hgrep`        | `history \| grep`       | Search command history    |
