# **Scripts**

![GitHub issues](https://img.shields.io/github/issues/Freaky2112/Scripts?style=flat-square&color=red) ![GitHub last commit](https://img.shields.io/github/last-commit/Freaky2112/Scripts?style=flat-square) ![GitHub license](https://img.shields.io/github/license/Freaky2112/Scripts?style=flat-square&color=blue) ![Build Status](https://img.shields.io/badge/build-passing-brightgreen.svg)

![ShellCheck](https://img.shields.io/badge/code%20quality-shellcheck-brightgreen?style=flat-square) ![OS](https://img.shields.io/badge/OS-Linux-blue?style=flat-square) ![Contributions](https://img.shields.io/badge/contributions-welcome-orange.svg)

![Stars](https://img.shields.io/github/stars/Freaky2112/Scripts)

A structured, modular collection of Bash scripts designed to automate common system tasks for developers, administrators, and power users. Each script is lightweight, self-contained, and focused on solving a specific problem clearly and reliably.

---

## **📌 About**

This repository serves as both a **ready-to-use toolbox** and a **learning reference** for clean, practical shell scripting. The tools included help streamline system diagnostics, automation, networking, backups, cleanup, and more — all while staying portable and easy to maintain.

The project emphasizes:

* **Simplicity & Clarity** — Readable and easy to adapt scripts
* **Modularity** — Each utility lives in its own folder
* **Portability** — Works on most Linux systems
* **Practical Utility** — Tools that solve real everyday problems
* **Selective Installation** — Install only what you need via the included installer

Whether you're automating repetitive tasks or building your own CLI tooling, these scripts provide a clean and organized foundation.

---

## **✨ Features**

Here’s what you’ll find inside:

### **System & Hardware Tools**

* Disk space checks
* System information summary
* Public IP lookup
* Hardware/network helpers

### **Process & Session Management**

* Process killer / analyzer
* Tmux session manager
* Service helpers

### **Networking & Security**

* SSH key management menu
* Password generator
* IP and connectivity utilities

### **Cleanup & Maintenance**

* Temporary file cleanup
* Log cleanup helpers
* System tidy scripts

### **Backup & Sync**

* Interactive rsync wrapper
* Smart file operations

### **Misc Utilities**

* Wrapper scripts
* Menu-driven helpers
* Quality-of-life automation scripts

*(Your actual list may vary — scripts are organized by folder for easy navigation.)*

---

## **📂 Repository Structure**

```
Scripts/
 ├── ScriptName1/
 │    ├── script.sh
 │    └── README.md
 ├── ScriptName2/
 ├── install
 ├── uninstall
 └── README.md  (this file)
```

Each script folder contains:

* The standalone script
* Any required assets or helper files
* A mini-README if needed

---

## **🚀 Installation**

You can install scripts system-wide or selectively.

### **1. Clone the repository**

```bash
git clone https://github.com/Freaky2112/Scripts.git
cd Scripts
```

### **2. Run the installer**

```bash
./install
```

The installer allows you to:

* Install everything
* Install only selected scripts
* Install to your PATH automatically

---

## **🧪 Usage**

Each utility is designed to be used like a normal Linux command once installed.

Examples:

```bash
disk_usage
tmux_manager
password_gen
cleanup_temp
check_public_ip
```

Or run any script manually:

```bash
./ScriptName/script.sh
```

---

## **📄 License**

This project is licensed under the **MIT License**, allowing you to freely use, modify, and distribute the scripts.

---

## **🤝 Contributions**

Contributions, improvements, and script additions are welcome!
Feel free to open issues, submit pull requests, or suggest new utility ideas.

---

## **⭐ Support**

If you find this repo useful, consider starring it — it helps others discover it.
