#!/usr/bin/env python3
import os
import sys
import subprocess
import time
import select
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
        return True

def countdown_with_skip(seconds, message="Next scan in"):
    """Countdown timer that can be skipped by pressing Enter or 's'"""
    print(f"\n{message}:", end=" ", flush=True)
    
    for i in range(seconds, 0, -1):
        print(f"{i}...", end=" ", flush=True)
        
        # Check if user pressed a key (non-blocking)
        if sys.platform != 'win32':
            # Unix/Linux
            ready, _, _ = select.select([sys.stdin], [], [], 1)
            if ready:
                user_input = sys.stdin.readline().strip().lower()
                if user_input in ['s', 'skip', '']:
                    print("\n⏭️  Skipped!")
                    return 'skip'
        else:
            # Windows - just wait
            time.sleep(1)
    
    print("GO!\n")
    return 'continue'

def scan_document(save_directory=None, device=None):
    """Scan a document and save as PDF with auto-incrementing filename"""

    if save_directory is None:
        save_directory = os.getcwd()

    os.makedirs(save_directory, exist_ok=True)

    scan_num = get_next_scan_number(save_directory)
    filename = f"scan{scan_num:02d}.pdf"
    filepath = os.path.join(save_directory, filename)
    temp_image_path = os.path.join(save_directory, "temp_scan.tiff")

    print(f"📄 Starting scan #{scan_num}... Will save as: {filename}")

    try:
        cmd = [
            'scanimage',
            '--resolution', '600',
            '--mode', 'Lineart',
            '--format', 'tiff',
            '--output-file', temp_image_path
        ]

        if device:
            cmd.extend(['--device-name', device])

        print("⏳ Scanning at 600 DPI, Black & White mode...")

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=180)

        if result.returncode != 0:
            print(f"❌ Scan error: {result.stderr}")
            return False

        if not os.path.exists(temp_image_path):
            print("❌ Error: Scan file was not created.")
            return False

        print("🔄 Converting to PDF...")

        img = Image.open(temp_image_path)

        if img.mode not in ['RGB', 'L']:
            img = img.convert('RGB')

        img.save(filepath, "PDF", resolution=100.0)
        os.remove(temp_image_path)

        print(f"✅ Scan #{scan_num} complete! Saved as: {filepath}")
        return True

    except subprocess.TimeoutExpired:
        print("❌ Error: Scan timed out. The scanner may be busy or disconnected.")
        if os.path.exists(temp_image_path):
            os.remove(temp_image_path)
        return False
    except FileNotFoundError:
        print("❌ Error: 'scanimage' command not found.")
        print("Please install SANE: sudo apt-get install sane-utils")
        return False
    except Exception as e:
        print(f"❌ Error during scanning: {str(e)}")
        if os.path.exists(temp_image_path):
            os.remove(temp_image_path)
        return False

def auto_scan_mode(save_dir, device, delay):
    """Automatic scanning mode with countdown between scans"""
    scan_count = 0
    
    print("\n" + "="*60)
    print("🔄 AUTO-SCAN MODE ACTIVE")
    print("="*60)
    print(f"⏱️  Delay between scans: {delay} seconds")
    print(f"📁 Saving to: {save_dir}")
    print(f"⚙️  Settings: 600 DPI, Black & White")
    print("\nInstructions:")
    print("  • Place your first document on the scanner")
    print("  • After each scan, you have {delay}s to change pages")
    print("  • Press 's' + Enter during countdown to skip a scan")
    print("  • Press Ctrl+C to stop scanning")
    print("="*60)
    
    try:
        input("\n👉 Press Enter to start first scan...")
        
        while True:
            # Perform scan
            success = scan_document(save_dir, device)
            
            if success:
                scan_count += 1
                print(f"\n📊 Total scans completed: {scan_count}")
                
                # Countdown before next scan
                print(f"\n⏸️  Change your page now! You have {delay} seconds...")
                print("   (Press 's' + Enter to skip the next scan)")
                
                result = countdown_with_skip(delay, "⏱️  Next scan starting in")
                
                if result == 'skip':
                    print("Enter 'q' to quit or press Enter to continue: ", end="", flush=True)
                    choice = input().strip().lower()
                    if choice == 'q':
                        break
                    continue
            else:
                print("\n⚠️  Scan failed. Waiting before retry...")
                time.sleep(3)
                retry = input("Press Enter to retry, or 'q' to quit: ").strip().lower()
                if retry == 'q':
                    break
    
    except KeyboardInterrupt:
        print(f"\n\n✋ Scanning stopped by user.")
        print(f"📊 Total scans completed: {scan_count}")

def manual_scan_mode(save_dir, device):
    """Manual scanning mode - press Enter for each scan"""
    scan_count = 0
    
    print("\n" + "="*60)
    print("👆 MANUAL SCAN MODE")
    print("="*60)
    print(f"📁 Saving to: {save_dir}")
    print(f"⚙️  Settings: 600 DPI, Black & White")
    print("\nInstructions:")
    print("  • Place document on scanner")
    print("  • Press Enter when ready to scan")
    print("  • Press Ctrl+C to quit")
    print("="*60 + "\n")
    
    try:
        while True:
            input("👉 Press Enter to scan (or Ctrl+C to quit)...")
            if scan_document(save_dir, device):
                scan_count += 1
                print(f"📊 Total scans: {scan_count}\n")
    except KeyboardInterrupt:
        print(f"\n\n✋ Scanning stopped.")
        print(f"📊 Total scans completed: {scan_count}")

def main():
    print("=" * 60)
    print("  HP M130nw Document Scanner - Auto & Manual Modes")
    print("=" * 60)
    print()

    print("🔍 Checking for scanner...")
    if not check_scanner():
        print("\n⚠️  Troubleshooting:")
        print("  1. Install SANE: sudo apt-get install sane-utils")
        print("  2. Check network: ping 192.168.22.168")
        print("  3. Try: sudo sane-find-scanner")
        print("  4. Add to group: sudo usermod -a -G scanner $USER")
        return

    print()

    # Get save directory
    save_dir = input("📁 Enter save directory (press Enter for current folder): ").strip()
    if not save_dir:
        save_dir = os.getcwd()

    print(f"\n✅ Scans will be saved to: {save_dir}\n")

    # Choose mode
    print("Choose scanning mode:")
    print("  1. AUTO-SCAN mode (automatic scanning with countdown)")
    print("  2. MANUAL mode (press Enter for each scan)")
    
    mode = input("\nEnter choice (1 or 2, default=1): ").strip()
    
    device = None  # Will use default scanner
    
    if mode == '2':
        manual_scan_mode(save_dir, device)
    else:
        # Auto-scan mode - get delay preference
        print("\nHow many seconds between scans?")
        print("  Recommended: 8-15 seconds (gives time to flip pages)")
        delay_input = input("Enter delay in seconds (default=10): ").strip()
        
        try:
            delay = int(delay_input) if delay_input else 10
            if delay < 3:
                print("⚠️  Minimum delay is 3 seconds. Using 3.")
                delay = 3
            elif delay > 60:
                print("⚠️  Maximum delay is 60 seconds. Using 60.")
                delay = 60
        except ValueError:
            print("⚠️  Invalid input. Using default of 10 seconds.")
            delay = 10
        
        auto_scan_mode(save_dir, device, delay)

    print("\n👋 Scanner program closed.")
    print(f"📁 Your scans are in: {save_dir}")

if __name__ == "__main__":
    main()