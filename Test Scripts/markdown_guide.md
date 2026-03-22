# Markdown Guidelines & Examples

## 1. Start With a Clear Title

Use `#` for the main title of your document.

```md
# My Project Documentation
```

## 2. Use Headings to Structure Your Content

`#` → Title
`##` → Sections
`###` → Subsections

```md
## Installation
### Requirements
```

## 3. Keep Paragraphs Short

Markdown prefers clean spacing.

## 4. Use Bullet Lists for Clarity

```md
- Item one
- Item two
- Item three
```

Numbered list:

```md
1. First step
2. Second step
```

## 5. Use Bold/Italic for Emphasis

```md
**Bold text**
*Italic text*
```

## 6. Add Code Blocks

```md
```bash
sudo apt install nginx
```

    ## 7. Blockquotes
    ```md
    >**Note:** Backup your files before continuing.

## 8. Tables

```md
| Name | Type | Notes |
|------|------|-------|
| API  | REST | v1.0  |
| Auth | OIDC | OAuth2 |
```

## 9. Links and Images

```md
[OpenAI](https://www.openai.com)
![Alt text](./image.png)
```

## 10. Horizontal Lines

```md
---
```

---

# Example: README.md

```md
# My Awesome Project

This project is a simple example showing how to structure a README file in Markdown.

---

## 🚀 Features
- Fast
- Easy to use
- Well structured

---

## 📦 Installation
```bash
git clone https://github.com/username/project.git
cd project
npm install
```

## 🛠 Usage

```bash
npm start
```

    ---

    # Example: Documentation Page
    ```md
    # Network Setup Guide

    This document explains how to configure basic VLANs on an EdgeRouter.

    ## Requirements
    - EdgeRouter X
    - Firmware 2.0+
    - Access to CLI

    ## VLAN Creation
    ### Step 1 — Create VLAN Interface
    ```bash
    set interfaces ethernet eth0 vif 10 address 192.168.10.1/24

### Step 2 --- Assign DHCP

```bash
set service dhcp-server shared-network-name VLAN10 subnet 192.168.10.0/24 range 0 start 192.168.10.100
set service dhcp-server shared-network-name VLAN10 subnet 192.168.10.0/24 range 0 stop 192.168.10.200
```

## Testing

```bash
show interfaces
```

    ---

    # Example: Notes.md
    ```md
    # System Notes

    ## To-Do
    - [x] Install updates
    - [ ] Configure backups
    - [ ] Add monitoring

    ## Commands
    ### Update system
    ```bash
    sudo apt update && sudo apt upgrade -y

### Check disk

```bash
df -h
```

## References

- Internal wiki
- Vendor documentation \`\`\`
-
