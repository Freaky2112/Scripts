# Network information
alias lip="hostname -I"
alias wip="curl -s icanhazip.com"

# Network connections
alias ports="sudo ss -tulpn"
alias openports="sudo ss -lntup"
alias conns="ss -tunap"
alias established="ss -tn state established"

# Connectivity
alias pingg="ping -c 4 8.8.8.8"

# Routing
alias route="ip route"

# DNS
alias dns="dig"
alias digg="dig +short"

# Network interfaces
alias ipa="ip -c a"

# HTTP
alias headers="curl -I"