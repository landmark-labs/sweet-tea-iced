# =================================================================
# Stage 1: Builder - Installs tools and builds dependencies
# =================================================================
FROM nvidia/cuda:12.8.1-devel-ubuntu22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies & Python 3.12
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    git curl nodejs npm \
    python3.13 python3.13-venv python3.13-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /root/.cache

# Configure Python 3.13 as default (required for SageAttention3)
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1 && \
    update-alternatives --set python3 /usr/bin/python3.13 && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.13 && \
    python3.13 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# Install common build tools and libraries
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential cmake pkg-config \
    libssl-dev libffi-dev \
    libgl1-mesa-dev libglib2.0-0 \
    ca-certificates \
    zlib1g-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff5-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    tk-dev \
    tcl-dev \
    libopenjp2-7-dev \
    libimagequant-dev \
    libxcb1-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /root/.cache

# Configure CUDA environment
ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH}
ENV PATH=/usr/local/cuda/bin:${PATH}

# Pip configuration
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_DEFAULT_TIMEOUT=100

# Build arguments
ARG INDEX_URL=https://download.pytorch.org/whl/cu128
ARG COMFYUI_COMMIT
ARG APP_MANAGER_VERSION=1.2.2
ARG CIVITAI_DOWNLOADER_VERSION=2.1.0

WORKDIR /

# Copy and prepare scripts
COPY scripts/install_comfyui_optimized.sh \
    scripts/install_civitai_model_downloader.sh \
    scripts/install_runpod_utils.sh \
    /scripts/

RUN chmod 755 /scripts/*.sh

# Install system dependencies for pillow-simd
RUN set -eux; \
    apt-get update -o Dir::Etc::sourcelist="sources.list" -o Dir::Etc::sourceparts="-"; \
    apt-get install -y --no-install-recommends \
    zlib1g-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff5-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    tk-dev \
    tcl-dev \
    libopenjp2-7-dev \
    libimagequant-dev \
    libxcb1-dev; \
    rm -rf /var/lib/apt/lists/*

# Fix CRLF line endings
RUN find /scripts -name "*.sh" -exec sed -i 's/\r$//' {} \;

# Run optimized installer
RUN bash /scripts/install_comfyui_optimized.sh \
    --index-url "${INDEX_URL}" \
    --comfyui-commit "${COMFYUI_COMMIT}" \
    --civitai-downloader-version "${CIVITAI_DOWNLOADER_VERSION}"

# Install RunPod Utils (tusd, runpod-uploader)
RUN bash /scripts/install_runpod_utils.sh

# Install Civitai Model Downloader
RUN bash /scripts/install_civitai_model_downloader.sh

# =================================================================
# Stage 2: Runtime - Optimized runtime image
# =================================================================
FROM nvidia/cuda:12.8.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    git \
    pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common && \
    add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl wget git git-lfs \
    nano vim less \
    tini \
    aria2 \
    sudo \
    nginx \
    openssh-server \
    ffmpeg \
    unzip zip tar \
    htop procps psmisc netcat-openbsd \
    libgl1 libglib2.0-0 \
    libsm6 libxrender1 libxext6 libxrandr2 \
    libxfixes3 libxi6 libxinerama1 libxcomposite1 libxdamage1 \
    libxss1 libxtst6 libxcursor1 libx11-6 libxft2 \
    zlib1g zlib1g-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff5-dev \
    libwebp-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libopenjp2-7-dev \
    libimagequant-dev \
    libxcb1-dev \
    openssl libssl-dev \
    google-perftools \
    python3.13 python3.13-venv python3.13-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x (required for Sweet Tea Studio)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    node --version && npm --version

# Install FileBrowser
RUN FB_VERSION=2.30.0 && \
    ARCH=amd64 && \
    curl -L "https://github.com/filebrowser/filebrowser/releases/download/v${FB_VERSION}/linux-${ARCH}-filebrowser.tar.gz" -o /tmp/filebrowser.tar.gz && \
    tar -xzf /tmp/filebrowser.tar.gz -C /usr/local/bin filebrowser && \
    chmod +x /usr/local/bin/filebrowser && \
    rm /tmp/filebrowser.tar.gz

# Install Code Server
RUN CS_VERSION=4.96.4 && \
    ARCH=amd64 && \
    curl -fOL "https://github.com/coder/code-server/releases/download/v${CS_VERSION}/code-server_${CS_VERSION}_${ARCH}.deb" && \
    dpkg -i "code-server_${CS_VERSION}_${ARCH}.deb" && \
    rm "code-server_${CS_VERSION}_${ARCH}.deb"

# Configure Python (3.13 required for SageAttention3)
RUN ln -sf /usr/bin/python3.13 /usr/local/bin/python3 && \
    ln -sf /usr/bin/python3.13 /usr/local/bin/python && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.13 && \
    python3.13 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# Create user and directories
RUN useradd -m -s /bin/bash -G sudo comfy && \
    mkdir -p /opt/ComfyUI /workspace /data /models /config /logs && \
    chown -R comfy:comfy /opt/ComfyUI /workspace /data /models /config /logs && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Copy artifacts from builder
COPY --from=builder /usr/local /usr/local
COPY --from=builder /opt/ComfyUI /opt/ComfyUI

ENV PATH=/usr/local/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH}

# Setup data directories
RUN mkdir -p /data/input /data/output /data/temp && \
    chown -R comfy:comfy /data

# Configure SSH
RUN mkdir -p /run/sshd /var/run/sshd && \
    ssh-keygen -A && \
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config && \
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Install CLI tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends jq ranger mc tree fzf ripgrep fd-find && \
    rm -rf /var/lib/apt/lists/*

# Environment variables
ENV LD_PRELOAD=libtcmalloc_minimal.so.4
ENV CC=gcc
ENV CXX=g++

ARG RELEASE=2.1.0-sage3
ENV TEMPLATE_VERSION=${RELEASE} \
    COMFYUI_PATH=/opt/ComfyUI \
    VENV_PATH=/opt/ComfyUI/venv \
    PATH="/opt/ComfyUI/venv/bin:${PATH}" \
    WORKSPACE_PATH=/workspace \
    FROZEN_COMMIT=${COMFYUI_COMMIT}

WORKDIR /

# Copy runtime scripts and config
COPY scripts/ /scripts/
COPY config/ /config/
COPY config/nginx.conf /etc/nginx/nginx.conf
COPY start_optimized.sh /start_optimized.sh

RUN chmod 755 /scripts/*.sh /start_optimized.sh && \
    find /scripts -name "*.sh" -exec sed -i 's/\r$//' {} \; && \
    sed -i 's/\r$//' /start_optimized.sh

# Reset host keys
RUN rm -f /etc/ssh/ssh_host_*

EXPOSE 22 3000 5173 7777 7778 8000 8188 8888 8889 2998 8080 8081 9999

CMD ["/start_optimized.sh"]
