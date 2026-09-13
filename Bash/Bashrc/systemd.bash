# Systemd
alias sstatus="sudo systemctl status"
alias srestart="sudo systemctl restart"
alias sstart="sudo systemctl start"
alias sstop="sudo systemctl stop"
alias senable="sudo systemctl enable"
alias sdisable="sudo systemctl disable"

# Services
alias services="systemctl --type=service --state=running"
alias failed="systemctl --failed"