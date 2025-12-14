#!/bin/bash
# =============================================================================
# Sweet Tea Studio Setup & Start Script
# Clones, installs, and starts Sweet Tea Studio (frontend + backend)
# =============================================================================

set -e

STS_PATH="${SWEET_TEA_PATH:-/opt/sweet-tea-studio}"
STS_REPO="${SWEET_TEA_REPO:-https://github.com/landmark-labs/sweet-tea-studio.git}"
LOG_DIR="/workspace/logs"

mkdir -p "$LOG_DIR"

echo "[sweet-tea] Starting Sweet Tea Studio setup..."

# Clone repository if not present
if [ ! -d "$STS_PATH" ]; then
    echo "[sweet-tea] Cloning repository..."
    git clone "$STS_REPO" "$STS_PATH"
else
    echo "[sweet-tea] Repository already exists at $STS_PATH"
    # Optional: pull latest changes
    if [ "${SWEET_TEA_AUTO_UPDATE:-true}" = "true" ]; then
        echo "[sweet-tea] Checking for updates..."
        cd "$STS_PATH"
        git fetch origin
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "$LOCAL")
        if [ "$LOCAL" != "$REMOTE" ]; then
            echo "[sweet-tea] Updating to latest version..."
            git pull
        else
            echo "[sweet-tea] Already up to date."
        fi
    fi
fi

# Setup and start Backend
echo "[sweet-tea] Setting up backend..."
cd "$STS_PATH/backend"

if [ ! -d "venv" ]; then
    echo "[sweet-tea] Creating backend virtual environment..."
    python3 -m venv venv
fi

source venv/bin/activate
echo "[sweet-tea] Installing backend dependencies..."
pip install --no-cache-dir -q -r requirements.txt
deactivate

echo "[sweet-tea] Starting backend on port 8000..."
source venv/bin/activate
nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > "$LOG_DIR/sweet-tea-backend.log" 2>&1 &
BACKEND_PID=$!
deactivate
echo "[sweet-tea] Backend started (PID: $BACKEND_PID)"

# Setup and start Frontend
echo "[sweet-tea] Setting up frontend..."
cd "$STS_PATH/frontend"

if [ ! -d "node_modules" ]; then
    echo "[sweet-tea] Installing frontend dependencies..."
    npm install --silent
fi

echo "[sweet-tea] Starting frontend on port 5173..."
nohup npm run dev -- --host 0.0.0.0 --port 5173 > "$LOG_DIR/sweet-tea-frontend.log" 2>&1 &
FRONTEND_PID=$!
echo "[sweet-tea] Frontend started (PID: $FRONTEND_PID)"

echo "[sweet-tea] ✅ Sweet Tea Studio is running!"
echo "[sweet-tea]    Frontend: http://localhost:5173 (via nginx: /studio/)"
echo "[sweet-tea]    Backend:  http://localhost:8000 (via nginx: /sts-api/)"
echo "[sweet-tea]    Logs: $LOG_DIR/sweet-tea-*.log"
