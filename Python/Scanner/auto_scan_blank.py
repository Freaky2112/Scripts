#!/usr/bin/env python3
import os
import sys
import subprocess
import time
import select
from datetime import datetime
import numpy as np

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

def is_blank_page(image_path, threshold=95):
    """
    Detect if a scanned page is blank/white
    
    Args:
        image_path: Path to the image file
        threshold: Percentage of white pixels needed (0-100). Default 95%
    
    Returns:
        True if page is blank, False otherwise
    """
    try:
        img = Image.open(image_path)
        
        # Convert to grayscale for analysis
        if img.mode != 'L':
            img = img.convert('L')
        
        # Convert to numpy array for fast analysis
        img_array = np.array(img)
        
        # Calculate percentage of white/near-white pixels
        # Consider pixels > 240 as "white" (on 0-255 scale)
        white_pixels = np.sum(img_array > 240)
        total_pixels = img_array.size
        white_percentage = (white_pixels / total_pixels) * 100
        
        print(f"   📊 Page whiteness: {white_percentage:.1f}%", end="")
        
        is_blank = white_percentage >= threshold
        
        if is_blank:
            print(" ← BLANK PAGE DETECTED! 🎯")
        else:
            print(" ← Content detected ✓")
        
        return is_blank
        
    except Exception as e:
        print(f"   ⚠️  Error analyzing image: {e}")
        return False

def countdown_with_skip(seconds, message="Next scan in"):
    """Countdown timer that can be skipped by pressing Enter or 's'"""
    print(f"\n{message}:", end=" ", flush=True)
    
    for i in range(seconds, 0, -1):
        print(f"{i}...", end=" ", flush=True)
        
        # Check if user pressed a key (non-blocking)
        if sys.platform != 'win32':
            ready, _, _ = select.select([sys.stdin], [], [], 1)
            if ready:
                user_input = sys.stdin.readline().strip().lower()
                if user_input in ['s', 'skip', '']:
                    print("\n⏭️  Skipped!")
                    return 'skip'
        else:
            time.sleep(1)
    
    print("GO!\n")
    return 'continue'

def scan_document(save_directory=None, device=None, check_blank=False, blank_threshold=95):
    """
    Scan a document and save as PDF with auto-incrementing filename
    
    Returns:
        'success' - scan completed and saved
        'blank' - scan completed but page was blank
        'error' - scan failed
    """

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
            return 'error'

        if not os.path.exists(temp_image_path):
            print("❌ Error: Scan file was not created.")
            return 'error'

        # Check if page is blank BEFORE converting to PDF
        is_blank = False
        if check_blank:
            print("🔍 Analyzing page content...")
            is_blank = is_blank_page(temp_image_path, blank_threshold)

        print("🔄 Converting to PDF...")

        img = Image.open(temp_image_path)

        if img.mode not in ['RGB', 'L']:
            img = img.convert('RGB')

        img.save(filepath, "PDF", resolution=100.0)
        os.remove(temp_image_path)

        if is_blank:
            print(f"⚪ Blank page saved as: {filepath}")
            return 'blank'
        else:
            print(f"✅ Scan #{scan_num} complete! Saved as: {filepath}")
            return 'success'

    except subprocess.TimeoutExpired:
        print("❌ Error: Scan timed out. The scanner may be busy or disconnected.")
        if os.path.exists(temp_image_path):
            os.remove(temp_image_path)
        return 'error'
    except FileNotFoundError:
        print("❌ Error: 'scanimage' command not found.")
        print("Please install SANE: sudo apt-get install sane-utils")
        return 'error'
    except Exception as e:
        print(f"❌ Error during scanning: {str(e)}")
        if os.path.exists(temp_image_path):
            os.remove(temp_image_path)
        return 'error'

def auto_scan_mode(save_dir, device, delay, blank_detection=True, blank_threshold=95, delete_blank=True):
    """Automatic scanning mode with countdown between scans and blank page detection"""
    scan_count = 0
    
    print("\n" + "="*70)
    print("🔄 AUTO-SCAN MODE ACTIVE")
    if blank_detection:
        print("🎯 BLANK PAGE DETECTION: ENABLED")
    print("="*70)
    print(f"⏱️  Delay between scans: {delay} seconds")
    print(f"📁 Saving to: {save_dir}")
    print(f"⚙️  Settings: 600 DPI, Black & White")
    
    if blank_detection:
        print(f"\n🎯 Smart Stop Feature:")
        print(f"   • Scans will analyze each page")
        print(f"   • When a blank/white page is detected (>{blank_threshold}% white)")
        print(f"   • Scanning will automatically STOP")
        print(f"   • Blank page will be {'DELETED' if delete_blank else 'KEPT'}")
        print(f"\n💡 TIP: Place a blank sheet when you're done scanning!")
    
    print("\nInstructions:")
    print("  • Place your first document on the scanner")
    print(f"  • After each scan, you have {delay}s to change pages")
    print("  • Press 's' + Enter during countdown to skip a scan")
    if blank_detection:
        print("  • Place a BLANK PAGE when finished to auto-stop")
    print("  • Press Ctrl+C to stop manually")
    print("="*70)
    
    try:
        input("\n👉 Press Enter to start first scan...")
        
        while True:
            # Perform scan
            result = scan_document(save_dir, device, 
                                  check_blank=blank_detection, 
                                  blank_threshold=blank_threshold)
            
            if result == 'success':
                scan_count += 1
                print(f"\n📊 Total scans completed: {scan_count}")
                
                # Countdown before next scan
                print(f"\n⏸️  Change your page now! You have {delay} seconds...")
                print("   (Press 's' + Enter to skip the next scan)")
                
                countdown_result = countdown_with_skip(delay, "⏱️  Next scan starting in")
                
                if countdown_result == 'skip':
                    print("Enter 'q' to quit or press Enter to continue: ", end="", flush=True)
                    choice = input().strip().lower()
                    if choice == 'q':
                        break
                    continue
            
            elif result == 'blank':
                print("\n" + "="*70)
                print("🎯 BLANK PAGE DETECTED - AUTO-STOPPING!")
                print("="*70)
                
                if delete_blank:
                    # Get the last scan number and delete it
                    last_scan_num = get_next_scan_number(save_dir) - 1
                    blank_file = os.path.join(save_dir, f"scan{last_scan_num:02d}.pdf")
                    if os.path.exists(blank_file):
                        os.remove(blank_file)
                        print(f"🗑️  Deleted blank page: scan{last_scan_num:02d}.pdf")
                else:
                    scan_count += 1
                    print(f"📄 Blank page kept in files")
                
                print(f"\n✅ Scanning session complete!")
                print(f"📊 Total content pages scanned: {scan_count}")
                break
            
            else:  # error
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
            result = scan_document(save_dir, device)
            if result in ['success', 'blank']:
                scan_count += 1
                print(f"📊 Total scans: {scan_count}\n")
    except KeyboardInterrupt:
        print(f"\n\n✋ Scanning stopped.")
        print(f"📊 Total scans completed: {scan_count}")

def main():
    print("=" * 70)
    print("  HP M130nw Scanner - Auto-Scan with Blank Page Detection 🎯")
    print("=" * 70)
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
    print("  1. AUTO-SCAN mode with BLANK PAGE DETECTION (recommended! 🎯)")
    print("  2. AUTO-SCAN mode without blank detection")
    print("  3. MANUAL mode (press Enter for each scan)")
    
    mode = input("\nEnter choice (1, 2, or 3, default=1): ").strip()
    
    device = None  # Will use default scanner
    
    if mode == '3':
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
        
        # Blank detection settings
        blank_detection = (mode != '2')
        blank_threshold = 95
        delete_blank = True
        
        if blank_detection:
            print("\n🎯 Blank Page Detection Settings:")
            print("  When should a page be considered 'blank'?")
            print("  95% = very strict (almost pure white)")
            print("  90% = normal (slightly marked pages still count as blank)")
            print("  85% = lenient (pages with faint marks count as blank)")
            
            thresh_input = input("Enter threshold % (default=95): ").strip()
            try:
                blank_threshold = int(thresh_input) if thresh_input else 95
                if blank_threshold < 70:
                    blank_threshold = 70
                elif blank_threshold > 99:
                    blank_threshold = 99
            except ValueError:
                blank_threshold = 95
            
            delete_input = input("\nDelete the blank page after detection? (Y/n, default=Y): ").strip().lower()
            delete_blank = delete_input != 'n'
        
        auto_scan_mode(save_dir, device, delay, blank_detection, blank_threshold, delete_blank)

    print("\n👋 Scanner program closed.")
    print(f"📁 Your scans are in: {save_dir}")

if __name__ == "__main__":
    main()