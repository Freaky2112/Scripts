# SSH Agent
alias ssha='eval "$(ssh-agent -s)" && ssh-add ~/.ssh/your_private_key'

# SSH keys
alias sshlist="ssh-add -l"

# SSH configuration
alias sshconfig="nano ~/.ssh/config"

# SSH permissions
alias sshperm="chmod 700 ~/.ssh && chmod 600 ~/.ssh/*"

# Known hosts
alias sshhosts="cat ~/.ssh/known_hosts"