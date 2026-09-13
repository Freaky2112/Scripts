# System
alias kernel="uname -a"
alias os="cat /etc/os-release"
alias load="uptime"
alias mem="free -h"

# Power
alias reboot="sudo reboot"
alias shutdown="sudo shutdown -h now"

# Processes
alias psall="ps aux"
alias psg="ps aux | grep"
alias pgrep="pgrep -af"
alias top="htop"

# Services
alias services="systemctl --type=service --state=running"
alias failed="systemctl --failed"

# Hardware
alias dmesg="sudo dmesg --color=always"
alias pci="lspci"
alias usb="lsusb"