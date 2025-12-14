#!/usr/bin/env python3
"""
Quick script to zip outputs for download
Usage: python download_outputs.py [--last N] [--date YYYY-MM-DD]
"""
import os
import sys
import zipfile
import argparse
from datetime import datetime, timedelta
from pathlib import Path

def create_download_zip(output_dir="/workspace/sweettea/output", 
                       last_n=None, 
                       date_filter=None):
    """Create a zip of recent outputs for easy download"""
    
    files = []
    output_path = Path(output_dir)
    
    # Get all image files
    for ext in ['*.png', '*.jpg', '*.jpeg', '*.webp']:
        files.extend(output_path.glob(ext))
    
    # Sort by modification time
    files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
    
    # Filter by criteria
    if last_n:
        files = files[:last_n]
    elif date_filter:
        cutoff = datetime.strptime(date_filter, "%Y-%m-%d")
        files = [f for f in files 
                if datetime.fromtimestamp(f.stat().st_mtime) >= cutoff]
    
    if not files:
        print("No files to download")
        return None
    
    # Create zip with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    zip_path = f"/workspace/downloads/outputs_{timestamp}.zip"
    
    os.makedirs("/workspace/downloads", exist_ok=True)
    
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        for file in files:
            zf.write(file, file.name)
    
    size_mb = os.path.getsize(zip_path) / (1024 * 1024)
    print(f"Created {zip_path} ({size_mb:.1f} MB) with {len(files)} files")
    print(f"Download at: http://<pod-ip>:8888/files/downloads/{os.path.basename(zip_path)}")
    
    return zip_path

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--last", type=int, help="Download last N images")
    parser.add_argument("--date", help="Download images from date (YYYY-MM-DD)")
    args = parser.parse_args()
    
    create_download_zip(last_n=args.last, date_filter=args.date)
