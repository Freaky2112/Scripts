# Docker containers
alias dps="docker ps"
alias dpsa="docker ps -a"
alias dimg="docker images"

# Container management
alias dstart="docker start"
alias dstop="docker stop"
alias drestart="docker restart"
alias drm="docker rm"

# Container information
alias dlog="docker logs -f"
alias dstats="docker stats"
alias dtop="docker top"

# Docker storage
alias dockerdu="docker system df"

# Docker cleanup
alias dclean="docker system prune"

# Docker Compose
alias dcup="docker compose up -d"
alias dcdown="docker compose down"
alias dcrestart="docker compose restart"
alias dcps="docker compose ps"
alias dclog="docker compose logs -f"
alias dcpull="docker compose pull"

# Update Compose stack
alias dcupdate="docker compose pull && docker compose up -d"

# Rebuild Compose stack
alias dcrebuild="docker compose up -d --build"