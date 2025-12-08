#!/usr/bin/env python3
import os
import sys
import subprocess
from datetime import datetime

try:
    from PIL import Image
except ImportError:
    print("Installing required packages...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
    from PIL import Image

def get_next_scan_number(directory):
    """Find the next available scan number"""
    existing_files = [f for f in os.listdir(directory) if f.startswith("scan") and f.endswith(".pdf")]

    if not existing_files:
        return 1

    numbers = []
    for filename in existing_files:
        try:
            # Extract number from filename like "scan01.pdf"
            num_str = filename.replace("scan", "").replace(".pdf", "")
            numbers.append(int(num_str))
        except ValueError:
            continue

    return max(numbers) + 1 if numbers else 1

def check_scanner():
    """Check if scanner is available via SANE"""
    try:
        result = subprocess.run(['scanimage', '-L'], capture_output=True, text=True, timeout=30)
        if result.returncode == 0 and result.stdout.strip():
            print(f"Scanner found:")
            for line in result.stdout.strip().split('\n'):
                print(f"  {line}")
            return True
        else:
            print("No scanner detected.")
            return False
    except FileNotFoundError:
        print("Error: 'scanimage' not found. Please install SANE:")
        print("  sudo apt-get install sane-utils")
        return False
    except subprocess.TimeoutExpired:
        print("Scanner detection timed out (network scanner may be slow).")
        print("Trying to continue anyway...")
        return True  # Allow to continue even if detection times out

def scan_document(save_directory=None, device=None):
    """Scan a document and save as PDF with auto-incrementing filename"""

    # Use current directory if none specified
    if save_directory is None:
        save_directory = os.getcwd()

    # Create directory if it doesn't exist
    os.makedirs(save_directory, exist_ok=True)

    # Get next scan number
    scan_num = get_next_scan_number(save_directory)
    filename = f"scan{scan_num:02d}.pdf"
    filepath = os.path.join(save_directory, filename)
    temp_image_path = os.path.join(save_directory, "temp_scan.tiff")

    print(f"Starting scan... Will save as: {filename}")

    try:
        # Build scanimage command
        # --resolution 600: Max DPI
        # --mode Lineart: Black & White (also try "Gray" for grayscale)
        # --format tiff: Output format

        cmd = [
            'scanimage',
            '--resolution', '600',
            '--mode', 'Lineart',
            '--format', 'tiff',
            '--output-file', temp_image_path
        ]

        # Add device if specified
        if device:
            cmd.extend(['--device-name', device])

        print("Scanning at 600 DPI, Black & White mode...")
        print("Please wait, this may take a moment...")

        # Execute scan
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)

        if result.returncode != 0:
            print(f"Scan error: {result.stderr}")
            return False

        # Check if file was created
        if not os.path.exists(temp_image_path):
            print("Error: Scan file was not created.")
            return False

        print("Converting to PDF...")

        # Open and convert to PDF
        img = Image.open(temp_image_path)

        # Convert to RGB if necessary (for PDF compatibility)
        if img.mode not in ['RGB', 'L']:
            img = img.convert('RGB')

        # Save as PDF
        img.save(filepath, "PDF", resolution=100.0)

        # Clean up temp file
        os.remove(temp_image_path)

        print(f"✓ Scan complete! Saved as: {filepath}")
        print(f"  Next scan will be: scan{scan_num+1:02d}.pdf")
        return True

    except subprocess.TimeoutExpired:
        print("Error: Scan timed out. The scanner may be busy or disconnected.")
        if os.path.exists(temp_image_path):
            os.remove(temp_image_path)
        return False
    except FileNotFoundError:
        print("Error: 'scanimage' command not found.")
        print("Please install SANE: sudo apt-get install sane-utils")
        return False
    except Exception as e:
        print(f"Error during scanning: {str(e)}")
        if os.path.exists(temp_image_path):
            os.remove(temp_image_path)
        return False

def list_scanners():
    """List all available scanners"""
    try:
        result = subprocess.run(['scanimage', '-L'], capture_output=True, text=True, timeout=30)
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
        return None
    except:
        return None

def main():
    print("=" * 50)
    print("Auto-Incrementing Document Scanner (Linux)")
    print("=" * 50)
    print()

    # Check for scanner
    print("Checking for scanners (this may take a moment for network scanners)...")
    if not check_scanner():
        print("\nTroubleshooting:")
        print("  1. Install SANE: sudo apt-get install sane-utils")
        print("  2. Check network connection")
        print("  3. Add user to scanner group: sudo usermod -a -G scanner $USER")
        print("  4. Verify scanner IP is accessible: ping 192.168.22.168")
        return

    print()

    # Get scanner device (optional - will use default if not specified)
    device = None
    scanner_list = list_scanners()
    if scanner_list and '\n' in scanner_list:
        print("Multiple scanners found. Using first one.")
        print("To specify a scanner, edit the script.")

    # Get save directory
    save_dir = input("Enter save directory (press Enter for current folder): ").strip()
    if not save_dir:
        save_dir = os.getcwd()

    print(f"\nScans will be saved to: {save_dir}")
    print("Settings: 600 DPI, Black & White")
    print()

    while True:
        try:
            input("Press Enter to scan (or Ctrl+C to quit)...")
            scan_document(save_dir, device)
            print()
        except KeyboardInterrupt:
            print("\n\nScanner program closed.")
            sys.exit(0)

if __name__ == "__main__":
    main()