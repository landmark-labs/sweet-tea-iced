# Nginx Setup - Usage & Troubleshooting

## How Nginx Works in This Setup

Nginx acts as a reverse proxy to provide:
1. **Unified access** to all services
2. **Static file serving** (much faster than through ComfyUI)
3. **Download acceleration** for your outputs

## 🌐 Port Mapping

| Service | Direct Port | Nginx Port | What it Does |
|---------|------------|------------|--------------|
| ComfyUI | 3001 | 3000 | Main UI + file browser at /output/ |
| Code Server | 7778 | 7777 | IDE & Terminal |
| FileBrowser | 8889 | 8888 | Visual file manager |
| RunPod Uploader | 8081 | 8080 | File uploads |

## 📁 How to Access Files via Nginx

### Browse Output Images (Fast!)
Instead of using ComfyUI's slow file browser:
```
http://<pod-ip>:3000/output/
```
This serves files directly from disk - MUCH faster than through ComfyUI!

### Browse Input Images
```
http://<pod-ip>:3000/input/
```

### Access Downloaded Zips
```
http://<pod-ip>:3000/downloads/
```

### Direct Image URLs
You can link directly to any image:
```
http://<pod-ip>:3000/output/ComfyUI_00001.png
```

## 🔧 Troubleshooting Nginx

### Check if Nginx is Running
```bash
# Check nginx status
systemctl status nginx

# Or check if it's listening
netstat -tlnp | grep nginx

# Check nginx error log
tail -f /var/log/nginx/error.log
```

### Restart Nginx
```bash
# If nginx isn't working
systemctl restart nginx

# Or force reload config
nginx -s reload
```

### Test Nginx Config
```bash
# Check for syntax errors
nginx -t
```

### Common Issues & Fixes

#### Issue: "502 Bad Gateway" on port 3000
This means nginx is running but can't reach ComfyUI.

**Fix:**
```bash
# Make sure ComfyUI is running
comfyui status

# If not, start it
comfyui start

# Check if it's on the right port
netstat -tlnp | grep 3001
```

#### Issue: Can't access /output/ or /downloads/
This means the directory doesn't exist or has permission issues.

**Fix:**
```bash
# Create directories
mkdir -p /workspace/ComfyUI/output
mkdir -p /workspace/downloads

# Check permissions
ls -la /workspace/ComfyUI/
```

#### Issue: Nginx not starting at all
```bash
# Check what's using the ports
lsof -i :3000
lsof -i :7777
lsof -i :8888

# Kill conflicting processes if needed
kill -9 <PID>

# Start nginx manually
nginx
```

## 🚀 Using Nginx for Speed

### Why Use Nginx Routes?

**Slow way** (through ComfyUI):
- Click UI → ComfyUI processes request → Reads file → Sends through Python → You get file
- Speed: ~500KB/s

**Fast way** (through Nginx):
- Click link → Nginx serves file directly from disk
- Speed: ~50MB/s (100x faster!)

### Practical Examples

#### Download a batch of images quickly
```bash
# List all outputs via nginx (instant)
curl http://localhost:3000/output/ | grep -o 'href="[^"]*\.png"' | cut -d'"' -f2

# Download specific image
wget http://localhost:3000/output/ComfyUI_00001.png
```

#### Serve images to external tools
If you're using external tools or scripts, point them to:
```
http://<pod-ip>:3000/output/<filename>
```
Instead of going through ComfyUI's API.

## 📝 Configuration Location

The nginx config is at: `/etc/nginx/nginx.conf`

Key sections:
- **Port 3000**: Main proxy + static file serving
- **Port 7777**: Code Server proxy
- **Port 8888**: FileBrowser proxy  
- **Port 8080**: RunPod uploader proxy

## 🎯 Best Practices

1. **For viewing images**: Use `http://<pod-ip>:3000/output/` instead of ComfyUI's browser
2. **For downloading**: Create zips in `/workspace/downloads/` and access via `http://<pod-ip>:3000/downloads/`
3. **For large transfers**: Use nginx routes, not ComfyUI's API
4. **Check logs**: If something isn't working, check `/var/log/nginx/error.log`

## Testing Nginx Setup

Run this test script:
```bash
#!/bin/bash
echo "Testing Nginx setup..."

# Test if nginx is running
if pgrep nginx > /dev/null; then
    echo "✅ Nginx is running"
else
    echo "❌ Nginx is not running"
    echo "   Run: systemctl start nginx"
fi

# Test each endpoint
echo ""
echo "Testing endpoints:"

# Test ComfyUI proxy
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200\|301\|302"; then
    echo "✅ ComfyUI proxy (port 3000) is working"
else
    echo "❌ ComfyUI proxy not responding"
fi

# Test output directory
if curl -s http://localhost:3000/output/ | grep -q "Index of"; then
    echo "✅ Output directory browsing works"
else
    echo "❌ Output directory not accessible"
fi

# Test other services
for port in 7777 8888 8080; do
    if netstat -tln | grep -q ":$port "; then
        echo "✅ Service on port $port is listening"
    else
        echo "⚠️  No service on port $port"
    fi
done
```

Save this as `/workspace/test_nginx.sh` and run it to verify everything is working!