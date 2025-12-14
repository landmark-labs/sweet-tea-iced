#!/usr/bin/env python3
import psutil
import GPUtil
import time
from datetime import datetime

def monitor():
    while True:
        # CPU and Memory
        cpu = psutil.cpu_percent(interval=1)
        mem = psutil.virtual_memory()

        # GPU
        gpus = GPUtil.getGPUs()
        if gpus:
            gpu = gpus[0]
            gpu_mem = f"{gpu.memoryUsed:.0f}/{gpu.memoryTotal:.0f}MB"
            gpu_util = f"{gpu.load*100:.0f}%"
        else:
            gpu_mem = "N/A"
            gpu_util = "N/A"

        # Disk I/O
        disk = psutil.disk_io_counters()
        read_mb = disk.read_bytes / (1024*1024)
        write_mb = disk.write_bytes / (1024*1024)

        print(f"[{datetime.now().strftime('%H:%M:%S')}] "
              f"CPU: {cpu:.1f}% | "
              f"RAM: {mem.percent:.1f}% | "
              f"GPU: {gpu_util} | "
              f"VRAM: {gpu_mem} | "
              f"Disk R/W: {read_mb:.0f}/{write_mb:.0f} MB")

        time.sleep(5)

if __name__ == "__main__":
    monitor()
