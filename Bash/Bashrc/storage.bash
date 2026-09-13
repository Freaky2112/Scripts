# Storage
alias df="df -h"
alias disks="lsblk -f"
alias du="du -sh *"

# Find large files
alias bigfiles="sudo du -ah / | sort -rh | head -20"