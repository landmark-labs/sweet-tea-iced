#!/usr/bin/env python3
"""
Batch Workflow Helper for ComfyUI
Optimized for high-volume generation and selection workflow
"""

import os
import shutil
import json
import argparse
from datetime import datetime
from pathlib import Path
import hashlib

class BatchWorkflowManager:
    def __init__(self):
        self.temp_dir = Path("/opt/ComfyUI/temp")  # Fast local SSD
        self.output_dir = Path("/workspace/sweettea/output")  # Persistent network
        self.batch_dir = Path("/workspace/batches")  # Batch organization
        self.batch_dir.mkdir(exist_ok=True)
        
    def start_batch(self, name=None):
        """Start a new batch session"""
        if not name:
            name = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        batch_path = self.batch_dir / name
        batch_path.mkdir(exist_ok=True)
        
        # Create batch metadata
        metadata = {
            "name": name,
            "started": datetime.now().isoformat(),
            "temp_count": 0,
            "selected_count": 0,
            "status": "active"
        }
        
        with open(batch_path / "metadata.json", "w") as f:
            json.dump(metadata, f, indent=2)
        
        # Clear temp directory for fresh start
        if self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)
        self.temp_dir.mkdir(exist_ok=True)
        
        print(f"✅ Batch '{name}' started")
        print(f"📁 Temp: {self.temp_dir}")
        print(f"📁 Batch: {batch_path}")
        return name
    
    def list_temp(self, batch_name=None):
        """List all images in temp directory"""
        images = list(self.temp_dir.glob("*.png")) + \
                list(self.temp_dir.glob("*.jpg")) + \
                list(self.temp_dir.glob("*.webp"))
        
        images.sort(key=lambda x: x.stat().st_mtime, reverse=True)
        
        print(f"\n📋 Temp images ({len(images)} total):")
        for i, img in enumerate(images[:20], 1):  # Show last 20
            size_mb = img.stat().st_size / (1024*1024)
            age_min = (datetime.now().timestamp() - img.stat().st_mtime) / 60
            print(f"  {i:2d}. {img.name} ({size_mb:.1f}MB, {age_min:.0f}m ago)")
        
        if len(images) > 20:
            print(f"  ... and {len(images)-20} more")
        
        return images
    
    def select_images(self, indices, batch_name):
        """Move selected images from temp to persistent storage"""
        batch_path = self.batch_dir / batch_name
        batch_path.mkdir(exist_ok=True)
        
        images = self.list_temp()
        selected = []
        
        for idx in indices:
            if 0 < idx <= len(images):
                src = images[idx-1]
                
                # Generate unique name with hash prefix
                hash_prefix = hashlib.md5(src.read_bytes()).hexdigest()[:8]
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                new_name = f"{batch_name}_{hash_prefix}_{timestamp}{src.suffix}"
                
                # Copy to batch directory
                dst = batch_path / new_name
                shutil.copy2(src, dst)
                
                # Also copy to main output for immediate visibility
                output_dst = self.output_dir / new_name
                shutil.copy2(src, output_dst)
                
                selected.append(new_name)
                print(f"✅ Selected: {src.name} → {new_name}")
        
        # Update metadata
        metadata_path = batch_path / "metadata.json"
        if metadata_path.exists():
            with open(metadata_path, "r") as f:
                metadata = json.load(f)
            metadata["selected_count"] += len(selected)
            metadata["last_selection"] = datetime.now().isoformat()
            with open(metadata_path, "w") as f:
                json.dump(metadata, f, indent=2)
        
        print(f"\n📦 Moved {len(selected)} images to {batch_path}")
        return selected
    
    def quick_select(self, pattern, batch_name):
        """Select images by pattern (e.g., 'last5', '1-10', '1,3,5')"""
        images = list(self.temp_dir.glob("*.png")) + \
                list(self.temp_dir.glob("*.jpg"))
        images.sort(key=lambda x: x.stat().st_mtime, reverse=True)
        
        indices = []
        
        if pattern.startswith("last"):
            n = int(pattern[4:])
            indices = list(range(1, min(n+1, len(images)+1)))
        elif "-" in pattern:
            start, end = pattern.split("-")
            indices = list(range(int(start), int(end)+1))
        elif "," in pattern:
            indices = [int(x) for x in pattern.split(",")]
        else:
            indices = [int(pattern)]
        
        return self.select_images(indices, batch_name)
    
    def clear_temp(self, force=False):
        """Clear temp directory"""
        if not force:
            count = len(list(self.temp_dir.glob("*")))
            if count > 0:
                response = input(f"⚠️  Delete {count} temp files? (y/n): ")
                if response.lower() != 'y':
                    print("Cancelled")
                    return
        
        shutil.rmtree(self.temp_dir)
        self.temp_dir.mkdir(exist_ok=True)
        print("✅ Temp directory cleared")
    
    def batch_stats(self, batch_name=None):
        """Show statistics for batch(es)"""
        if batch_name:
            batches = [self.batch_dir / batch_name]
        else:
            batches = [d for d in self.batch_dir.iterdir() if d.is_dir()]
        
        print("\n📊 Batch Statistics:")
        print("-" * 60)
        
        total_selected = 0
        total_size = 0
        
        for batch in sorted(batches, reverse=True)[:10]:  # Last 10 batches
            metadata_path = batch / "metadata.json"
            if metadata_path.exists():
                with open(metadata_path, "r") as f:
                    metadata = json.load(f)
                
                batch_size = sum(f.stat().st_size for f in batch.glob("*.*") if f.suffix in ['.png', '.jpg', '.webp'])
                batch_size_mb = batch_size / (1024*1024)
                
                print(f"📁 {metadata['name']}")
                print(f"   Started: {metadata['started'][:19]}")
                print(f"   Selected: {metadata['selected_count']} images")
                print(f"   Size: {batch_size_mb:.1f} MB")
                
                total_selected += metadata['selected_count']
                total_size += batch_size
        
        print("-" * 60)
        print(f"Total: {total_selected} images, {total_size/(1024*1024):.1f} MB")
    
    def auto_organize(self, threshold_minutes=30):
        """Auto-organize old temp files"""
        now = datetime.now().timestamp()
        old_files = []
        
        for img in self.temp_dir.glob("*"):
            age_minutes = (now - img.stat().st_mtime) / 60
            if age_minutes > threshold_minutes:
                old_files.append(img)
        
        if old_files:
            print(f"Found {len(old_files)} files older than {threshold_minutes} minutes")
            archive_dir = self.batch_dir / "auto_archive" / datetime.now().strftime("%Y%m%d")
            archive_dir.mkdir(parents=True, exist_ok=True)
            
            for f in old_files:
                shutil.move(str(f), str(archive_dir / f.name))
            
            print(f"✅ Archived to {archive_dir}")

def main():
    parser = argparse.ArgumentParser(description="Batch workflow helper for ComfyUI")
    parser.add_argument("command", choices=["start", "list", "select", "clear", "stats", "auto"],
                       help="Command to execute")
    parser.add_argument("--batch", "-b", help="Batch name")
    parser.add_argument("--indices", "-i", help="Image indices to select (e.g., '1,3,5' or '1-10' or 'last5')")
    parser.add_argument("--force", "-f", action="store_true", help="Force operation without confirmation")
    parser.add_argument("--threshold", "-t", type=int, default=30, 
                       help="Age threshold in minutes for auto-organize")
    
    args = parser.parse_args()
    manager = BatchWorkflowManager()
    
    if args.command == "start":
        batch_name = manager.start_batch(args.batch)
        print(f"\nNext steps:")
        print(f"  1. Generate images in ComfyUI")
        print(f"  2. Run: batch list -b {batch_name}")
        print(f"  3. Run: batch select -b {batch_name} -i '1,3,5'")
        
    elif args.command == "list":
        manager.list_temp(args.batch)
        
    elif args.command == "select":
        if not args.batch:
            print("❌ Please specify batch name with --batch")
            return
        if not args.indices:
            print("❌ Please specify indices with --indices (e.g., '1,3,5' or 'last10')")
            return
        manager.quick_select(args.indices, args.batch)
        
    elif args.command == "clear":
        manager.clear_temp(args.force)
        
    elif args.command == "stats":
        manager.batch_stats(args.batch)
        
    elif args.command == "auto":
        manager.auto_organize(args.threshold)

if __name__ == "__main__":
    main()