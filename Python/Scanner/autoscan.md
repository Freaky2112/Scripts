# HP M130nw Auto-Scanner with Blank Page Detection 🎯

Automatic document scanning script for Linux with smart blank page detection to auto-stop scanning sessions.

## Features

* 🔄 **Auto-scan mode** - Automatically scans with configurable delays between pages
* 🎯 **Blank page detection** - Place a blank page when done and scanning stops automatically
* 📄 **Auto-incrementing filenames** - Scans saved as scan01.pdf, scan02.pdf, etc.
* ⚙️ **High quality** - 600 DPI, Black & White scanning
* 🗑️ **Smart cleanup** - Optionally deletes the blank page after detection
* ⏭️ **Skip option** - Press 's' during countdown to skip a scan
* 👆 **Manual mode** - Traditional press-Enter-to-scan option

## Requirements

### Hardware

* HP LaserJet Pro MFP M130nw (or compatible SANE-supported scanner)
* Network connection to scanner

### Software

* Linux (Debian/Ubuntu/Raspberry Pi OS, Fedora, Arch, etc.)
* Python 3
* SANE scanning tools
* Required Python libraries

## Installation

### Step 1: Install SANE (Scanner Access Now Easy)

**Debian/Ubuntu/Raspberry Pi OS:**

```bash
sudo apt update
sudo apt install sane-utils
```

**Fedora/RHEL:**

```bash
sudo dnf install sane-backends sane-backends-drivers-scanners
```

**Arch Linux:**

```bash
sudo pacman -S sane
```

### Step 2: Install Python Dependencies

**Debian/Ubuntu/Raspberry Pi OS:**

```bash
sudo apt install python3-numpy python3-pil
```

**Fedora/RHEL:**

```bash
sudo dnf install python3-numpy python3-pillow
```

**Arch Linux:**

```bash
sudo pacman -S python-numpy python-pillow
```

### Step 3: Add User to Scanner Group (Optional but Recommended)

```bash
sudo usermod -a -G scanner $USER
```

Then **log out and log back in** for the group change to take effect.

### Step 4: Verify Scanner Connection

Check if your scanner is detected:

```bash
scanimage -L
```

You should see output like:

```
device `hpaio:/net/HP_LaserJet_MFP_M130nw?ip=192.168.22.168' is a Hewlett-Packard HP_LaserJet_MFP_M130nw all-in-one
```

If not detected, check:

* Scanner is powered on
* Connected to same network
* Firewall isn't blocking scanner
* Try: `sudo sane-find-scanner`

### Step 5: Download the Script

Save the Python script as `autoscan.py` and make it executable:

```bash
chmod +x autoscan.py
```

## Usage

### Quick Start

```bash
python3 autoscan.py
```

Or if you made it executable:

```bash
./autoscan.py
```

### Scanning Workflow

1. **Start the script**
   ```bash
   python3 autoscan.py
   ```
2. **Choose save directory** (or press Enter for current folder)
3. **Select mode:**
   * **Mode 1** (Recommended): Auto-scan WITH blank page detection 🎯
   * **Mode 2** : Auto-scan WITHOUT blank detection
   * **Mode 3** : Manual mode (press Enter for each scan)
4. **Set delay** between scans (recommended: 10-15 seconds)
5. **Configure blank detection** (if using Mode 1):
   * Set whiteness threshold (default: 95%)
   * Choose to delete blank page (default: Yes)
6. **Start scanning:**
   * Place first document
   * Press Enter to begin
   * Script scans automatically with countdown
   * Flip pages during the countdown
7. **Stop scanning:**
   * **Mode 1** : Place a BLANK PAGE on scanner - it auto-detects and stops! 🎯
   * **Any mode** : Press Ctrl+C to stop manually
   * During countdown: Press 's' + Enter to skip next scan

### Example Session

```
🔄 AUTO-SCAN MODE ACTIVE
🎯 BLANK PAGE DETECTION: ENABLED
======================================================================
⏱️  Delay between scans: 10 seconds
📁 Saving to: /home/user/documents
⚙️  Settings: 600 DPI, Black & White

🎯 Smart Stop Feature:
   • Scans will analyze each page
   • When a blank/white page is detected (>95% white)
   • Scanning will automatically STOP
   • Blank page will be DELETED

💡 TIP: Place a blank sheet when you're done scanning!

👉 Press Enter to start first scan...

📄 Starting scan #1... Will save as: scan01.pdf
⏳ Scanning at 600 DPI, Black & White mode...
🔍 Analyzing page content...
   📊 Page whiteness: 23.4% ← Content detected ✓
🔄 Converting to PDF...
✅ Scan #1 complete! Saved as: /home/user/documents/scan01.pdf

📊 Total scans completed: 1

⏸️  Change your page now! You have 10 seconds...
   (Press 's' + Enter to skip the next scan)

⏱️  Next scan starting in: 10... 9... 8... 7... 6... 5... 4... 3... 2... 1... GO!

[After scanning several pages, you place a blank page...]

📄 Starting scan #5... Will save as: scan05.pdf
⏳ Scanning at 600 DPI, Black & White mode...
🔍 Analyzing page content...
   📊 Page whiteness: 97.3% ← BLANK PAGE DETECTED! 🎯

======================================================================
🎯 BLANK PAGE DETECTED - AUTO-STOPPING!
======================================================================
🗑️  Deleted blank page: scan05.pdf

✅ Scanning session complete!
📊 Total content pages scanned: 4
```

## Configuration Options

### Scan Settings

* **Resolution** : 600 DPI (hardcoded for quality)
* **Mode** : Lineart (Black & White)
* **Format** : PDF

### Blank Detection Settings

* **Threshold** : 85-99% (default: 95%)
* 95% = very strict (almost pure white)
* 90% = normal (slightly marked pages count as blank)
* 85% = lenient (pages with faint marks count as blank)

### Timing

* **Delay between scans** : 3-60 seconds (default: 10)
* Recommended: 10-15 seconds for manual page flipping

## Troubleshooting

### Scanner Not Detected

**Check network connection:**

```bash
ping <Your IP Address>  # Replace with your scanner's IP
```

**Find scanner manually:**

```bash
sudo sane-find-scanner
```

**Check SANE configuration:**

```bash
scanimage -L
```

**Add yourself to scanner group:**

```bash
sudo usermod -a -G scanner $USER
# Log out and back in
```

### Permission Denied Errors

```bash
sudo usermod -a -G scanner $USER
sudo usermod -a -G lp $USER
# Log out and log back in
```

### Scanner Times Out

* Increase timeout in script (line with `timeout=180`)
* Check if scanner is in sleep mode
* Verify network stability
* Try restarting scanner

### Blank Detection Too Sensitive/Not Sensitive Enough

When starting the script, adjust the threshold:

* **Too sensitive** (detecting content as blank): Lower threshold to 90% or 85%
* **Not sensitive enough** (not detecting blank pages): Raise threshold to 97% or 98%

### Python Package Errors

If you see "externally-managed-environment" error, use system packages:

```bash
# Don't use pip install!
# Use system package manager instead:
sudo apt install python3-numpy python3-pil  # Debian/Ubuntu
```

## File Output

Scans are saved with auto-incrementing names:

```
scan01.pdf
scan02.pdf
scan03.pdf
...
```

The script automatically finds the next available number, so you can run multiple scanning sessions in the same folder.

## Advanced Usage

### Specify Scanner Device

If you have multiple scanners, edit the script and set the `device` variable:

```python
device = "hpaio:/net/HP_LaserJet_MFP_M130nw?ip=192.168.22.168"
```

### Change Default Settings

Edit these variables in the `scan_document()` function:

* `--resolution`: Change DPI (default: 600)
* `--mode`: Change to 'Gray' for grayscale or 'Color' for color scans

### Run in Background

```bash
nohup python3 autoscan.py &
```

## Tips & Best Practices

1. **Keep a blank page handy** - Use it to signal the end of your scanning session
2. **Adjust delay for your workflow** - Longer for thick documents, shorter for thin pages
3. **Use the skip feature** - Press 's' during countdown if you need more time
4. **Check whiteness percentage** - If blank detection isn't working, adjust threshold
5. **Organize by project** - Create different folders for different scanning batches

## Credits

Created for HP LaserJet Pro MFP M130nw network scanner.

Uses:

* **SANE** - Scanner Access Now Easy
* **Pillow** - Python Imaging Library
* **NumPy** - Numerical computing for image analysis

## License

Free to use and modify. No warranty provided.

## Support

If you encounter issues:

1. Check scanner connection and power
2. Verify SANE installation: `scanimage -L`
3. Check Python dependencies are installed
4. Review scanner logs: `dmesg | grep -i scan`
5. Test manual scan: `scanimage --format=tiff > test.tiff`

---

**Happy Scanning!** 📄✨🎯
