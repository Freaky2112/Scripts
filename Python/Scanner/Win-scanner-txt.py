import os
import sys
from datetime import datetime

try:
    import win32com.client
except ImportError:
    print("Installing required packages...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "pywin32"])
    import win32com.client

def get_next_scan_number(directory):
    """Find the next available scan number"""
    existing_files = [f for f in os.listdir(directory) if f.startswith("scan") and f.endswith(".txt")]
    
    if not existing_files:
        return 1
    
    numbers = []
    for filename in existing_files:
        try:
            # Extract number from filename like "scan01.txt"
            num_str = filename.replace("scan", "").replace(".txt", "")
            numbers.append(int(num_str))
        except ValueError:
            continue
    
    return max(numbers) + 1 if numbers else 1

def scan_document(save_directory=None):
    """Scan a document and save as text file with auto-incrementing filename"""
    
    # Use current directory if none specified
    if save_directory is None:
        save_directory = os.getcwd()
    
    # Create directory if it doesn't exist
    os.makedirs(save_directory, exist_ok=True)
    
    # Get next scan number
    scan_num = get_next_scan_number(save_directory)
    filename = f"scan{scan_num:02d}.txt"
    filepath = os.path.join(save_directory, filename)
    
    print(f"Starting scan... Will save as: {filename}")
    
    try:
        # Create WIA DeviceManager
        device_manager = win32com.client.Dispatch("WIA.DeviceManager")
        
        # Check if any scanners are available
        if device_manager.DeviceInfos.Count == 0:
            print("Error: No scanners found. Please check:")
            print("  1. Scanner is connected and powered on (network or USB)")
            print("  2. Scanner drivers are installed")
            print("  3. Scanner appears in 'Devices and Printers'")
            print("  4. For network scanners: verify IP address is reachable")
            return False
        
        # Connect to the first available scanner
        device_info = device_manager.DeviceInfos.Item(1)
        device = device_info.Connect()
        
        print(f"Connected to: {device_info.Properties('Name').Value}")
        
        # Set scan properties
        try:
            device.Properties("6146").Value = 1200  # Max DPI horizontal
            device.Properties("6147").Value = 1200  # Max DPI vertical
            device.Properties("6153").Value = 1     # Black & White mode
            print("Settings: 1200 DPI, Black & White, OCR to Text")
        except:
            print("Using default scanner settings (attempting max DPI B&W)...")
        
        # Scan the document
        print("Scanning... Please wait.")
        image = device.Items(1).Transfer()
        
        # Try to get text using OCR if available
        try:
            # Try to use Windows OCR
            text = image.OCR()
            
            # Save as text file
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(text)
            
            print(f"✓ Scan complete! Saved as: {filepath}")
            print(f"  Text extracted: {len(text)} characters")
            print(f"  Next scan will be: scan{scan_num+1:02d}.txt")
            return True
            
        except:
            # OCR not available, try alternative method
            print("OCR not available through WIA, trying alternative method...")
            
            try:
                # Save as temporary image first
                temp_image_path = os.path.join(save_directory, "temp_scan.bmp")
                image.SaveFile(temp_image_path)
                
                # Try to use Windows.Media.Ocr via PowerShell
                ps_script = f'''
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
[Windows.Foundation.IAsyncOperation`1, Windows.Foundation, ContentType=WindowsRuntime] | Out-Null
[Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics, ContentType=WindowsRuntime] | Out-Null

$file = [System.IO.File]::OpenRead("{temp_image_path.replace(chr(92), chr(92)+chr(92))}")
$memStream = New-Object System.IO.MemoryStream
$file.CopyTo($memStream)
$file.Close()

$randomAccessStream = [System.IO.WindowsRuntimeStreamExtensions]::AsRandomAccessStream($memStream)
$decoder = [Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($randomAccessStream).GetResults()

$softwareBitmap = $decoder.GetSoftwareBitmapAsync().GetResults()

$ocrEngine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
$ocrResult = $ocrEngine.RecognizeAsync($softwareBitmap).GetResults()

$memStream.Close()

Write-Output $ocrResult.Text
'''
                
                import subprocess
                result = subprocess.run(['powershell', '-Command', ps_script], 
                                      capture_output=True, text=True, timeout=60)
                
                if result.returncode == 0 and result.stdout.strip():
                    text = result.stdout.strip()
                    
                    # Save as text file
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(text)
                    
                    # Clean up temp file
                    os.remove(temp_image_path)
                    
                    print(f"✓ Scan complete! Saved as: {filepath}")
                    print(f"  Text extracted: {len(text)} characters")
                    print(f"  Next scan will be: scan{scan_num+1:02d}.txt")
                    return True
                else:
                    raise Exception("PowerShell OCR failed")
                    
            except Exception as ocr_error:
                print(f"OCR failed: {str(ocr_error)}")
                print("\nWindows OCR not available. Options:")
                print("  1. Install Tesseract OCR: https://github.com/UB-Mannheim/tesseract/wiki")
                print("  2. Use Office Lens or other OCR software")
                print("  3. Scan as PDF instead (modify script)")
                
                # Clean up temp file if it exists
                if os.path.exists(temp_image_path):
                    os.remove(temp_image_path)
                return False
        
    except Exception as e:
        print(f"Error during scanning: {str(e)}")
        print("\nTroubleshooting tips:")
        print("  - Ensure scanner is turned on and ready")
        print("  - Check if other scanning software is open")
        print("  - Try restarting the scanner")
        print("  - For network scanners: verify network connection")
        return False

def main():
    print("=" * 50)
    print("Auto-Incrementing Document Scanner (Windows)")
    print("=" * 50)
    print()
    
    # You can change this to your preferred directory
    save_dir = input("Enter save directory (press Enter for current folder): ").strip()
    if not save_dir:
        save_dir = os.getcwd()
    
    print(f"\nScans will be saved to: {save_dir}")
    print()
    
    while True:
        input("Press Enter to scan (or Ctrl+C to quit)...")
        scan_document(save_dir)
        print()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nScanner program closed.")
        sys.exit(0)