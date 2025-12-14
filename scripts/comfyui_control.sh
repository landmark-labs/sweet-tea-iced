#!/bin/bash
# ComfyUI Control Script

case "$1" in
    start)
        echo "Starting ComfyUI..."
        cd /opt/ComfyUI
        source venv/bin/activate
        export PYTHONUNBUFFERED=1
        export LD_PRELOAD="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
        shift  # Remove 'start' from arguments
		export TRITON_CACHE_DIR=${TRITON_CACHE_DIR:-/opt/ComfyUI/triton-cache}
        python main.py --listen 0.0.0.0 --port 8188 "$@" > /workspace/logs/comfyui.log 2>&1 &
        echo "ComfyUI started with args: $@"
        echo "Log: /workspace/logs/comfyui.log"
        ;;
    stop)
        echo "Stopping ComfyUI..."
        PID=$(pgrep -f "python.*main.py.*port 8188")
        if [ -n "$PID" ]; then
            echo "Found ComfyUI process: $PID"
            kill "$PID"
            
            # Wait for process to exit
            TIMEOUT=10
            while kill -0 "$PID" 2>/dev/null && [ $TIMEOUT -gt 0 ]; do
                sleep 1
                ((TIMEOUT--))
            done
            
            if kill -0 "$PID" 2>/dev/null; then
                echo "Process $PID did not exit gracefully. Force killing..."
                kill -9 "$PID"
            else
                echo "ComfyUI stopped gracefully."
            fi
        else
            echo "ComfyUI is not running."
        fi
        ;;
    restart)
        $0 stop
        sleep 2
        shift  # Remove 'restart' from arguments
        $0 start "$@"
        ;;
    status)
        if pgrep -f "python.*main.py.*port 8188" > /dev/null; then
            echo "ComfyUI is running"
            echo "GPU Memory Usage:"
            nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits
        else
            echo "ComfyUI is not running"
        fi
        ;;
    log)
        tail -f /workspace/logs/comfyui.log
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|log} [additional args for ComfyUI]"
        echo "Example: $0 restart --preview-method auto"
        exit 1
        ;;
esac
