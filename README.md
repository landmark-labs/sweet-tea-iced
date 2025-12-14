# Optimized ComfyUI Docker for RunPod & Vast.ai

## 🚀 Key Features

### 1. **Direct R2 Sync Architecture**
- **Fast Startup**: Syncs models, nodes, and workflows directly from Cloudflare R2 to local SSD (`/opt/ComfyUI`) at startup.
- **High Performance**: Runs entirely on fast local NVMe storage. No slow network volume mounting.
- **Smart Sync**: Only downloads what's needed. Background sync allows immediate UI access.
- **Auto-Backup**: Automatically syncs your outputs and new models back to R2 on shutdown.

### 2. **High-Performance Optimizations**
- **CUDA 12.8 & PyTorch 2.7+**: Latest drivers and libraries for maximum performance.
- **SageAttention**: 2-2.5x speedup for attention operations (automatically enabled for supported GPUs).
- **TCMalloc**: Optimized memory allocation for reduced fragmentation.
- **Pillow-SIMD**: Accelerated image processing.

### 3. **Enhanced Tooling**
- **FileBrowser**: Web-based file manager (Port 8888).
- **Code Server**: VS Code in the browser (Port 7777).
- **ComfyUI Manager**: Pre-installed for easy node management.
- **Monitoring**: Real-time GPU/CPU/Memory tracking script.

## 📁 Directory Structure

```
/opt/ComfyUI/          # Local SSD - Main Application
├── models/            # Synced from R2
├── output/            # Synced to/from R2
├── input/             # Synced from R2
├── user/              # Synced to/from R2 (Workflows)
├── custom_nodes/      # Synced from R2
└── temp/              # Ephemeral temp files (fast, auto-cleared)

/workspace/            # Persistent Working Directory
├── logs/              # Startup and service logs
└── .code-server/      # IDE settings
```

## 🎮 Usage Guide

### Environment Variables
Set these in your RunPod/Vast.ai template:

- `R2_ACCOUNT_ID`: Your Cloudflare R2 Account ID
- `R2_ACCESS_KEY_ID`: Your R2 Access Key
- `R2_SECRET_ACCESS_KEY`: Your R2 Secret Key
- `R2_BUCKET`: Your R2 Bucket Name
- `COMFYUI_EXTRA_ARGS`: (Optional) Extra args for ComfyUI (e.g., `--preview-method auto`)

### Starting/Stopping ComfyUI

```bash
# Start ComfyUI (automatic on container start)
comfyui start

# Restart with new arguments
comfyui restart --highvram --preview-method auto

# Check status
comfyui status

# View logs
comfyui log
```

### File Management

- **Web Interface**: Access FileBrowser at `http://<pod-ip>:8888` (Default: admin/admin)
- **Download Outputs**:
  ```bash
  # Zip and download last 50 images
  python /workspace/download_outputs.py --last 50
  ```

### Performance Monitoring

```bash
# Real-time dashboard
python /workspace/monitor.py
```

## 🌐 Service Endpoints

| Service | Port | URL | Purpose |
|---------|------|-----|---------|
| **Sweet Tea Studio** | 3000 | http://<pod-ip>:3000/studio/ | Prompt Builder UI |
| Sweet Tea API | 3000 | http://<pod-ip>:3000/sts-api/ | Sweet Tea Backend |
| ComfyUI | 3000 | http://<pod-ip>:3000/ | Main ComfyUI UI |
| ComfyUI Direct | 8188 | http://<pod-ip>:8188 | Direct ComfyUI Access |
| Code Server | 7777 | http://<pod-ip>:7777 | IDE & Terminal |
| FileBrowser | 8888 | http://<pod-ip>:8888 | File Management |
| Nginx Proxy | 3000 | http://<pod-ip>:3000 | Unified Access |

> **Note**: Sweet Tea Studio starts **before** ComfyUI, so you can access it immediately while waiting for ComfyUI to initialize.

## 🚀 SageAttention Acceleration

This image includes **SageAttention**, an optimized attention mechanism that provides significant speedups (2x+) for high-resolution generation.

- **Automatic**: Enabled automatically for supported GPUs (RTX 3090/4090/5090, A100, H100).
- **Verification**: Check logs for "SageAttention enabled".
- **Disable**: Add `--use-pytorch-cross-attention` to `COMFYUI_EXTRA_ARGS` if you encounter issues.

## 🔄 R2 Sync Behavior

1. **Startup**:
   - Checks for R2 credentials.
   - Background syncs `models`, `custom_nodes`, `user`, `input`, `output` from R2 to `/opt/ComfyUI`.
   - ComfyUI starts immediately (files appear as they download).

2. **Shutdown**:
   - Automatically syncs changes in `output`, `user` (workflows), and `models` back to R2.

3. **Manual Sync**:
   - You can manually trigger syncs using `rclone` if needed, but the automatic scripts handle most cases.

## 🛠️ Troubleshooting

- **Sync Issues**: Check `/workspace/logs/startup.log` and `/workspace/logs/rclone_down.log`.
- **Permission Errors**: Run `chown -R comfy:comfy /opt/ComfyUI`.
- **Slow Startup**: Ensure R2 bucket is in the same region or close to your GPU provider for best speeds.

## 📦 Building the Image

```bash
./build_and_push.sh
```