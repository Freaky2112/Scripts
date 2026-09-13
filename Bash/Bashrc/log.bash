# Journal
alias logs="sudo journalctl -f"
alias sjournal="sudo journalctl -u"

# Boot logs
alias todaylogs="sudo journalctl --since today"
alias bootlogs="sudo journalctl -b"
alias klogs="sudo journalctl -k"

# Errors
alias errors="sudo journalctl -p err -b"