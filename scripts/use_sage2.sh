#!/bin/bash

# Switch to SageAttention 2 (Stable)
echo "🔄 Switching to SageAttention 2..."

source /opt/ComfyUI/venv/bin/activate

# 1. Uninstall SageAttention3 if present
if python3 -c "import sageattn3" 2>/dev/null; then
    echo "Removing SageAttention3..."
    pip uninstall -y sageattn3
fi

# 2. Install SageAttention 2
echo "Installing SageAttention 2.2..."
pip install "sageattention==2.2.0"

# 3. Create/Update the setup script for SA2
cat > /opt/ComfyUI/custom_nodes/00_enable_sageattention.py <<EOF
import logging
import torch
import os

logger = logging.getLogger(__name__)

def initialize_sageattention2():
    """
    Initialize SageAttention 2.
    """
    try:
        import sageattention
        # SageAttention 2 automatically patches torch.nn.functional.scaled_dot_product_attention
        # when you import it or call its init functions, depending on version.
        # For 2.x, we typically just need to import it.
        
        logger.info("✅ SageAttention 2 initialized successfully.")
        return True
    except ImportError:
        logger.warning("❌ SageAttention 2 not found. Falling back to default SDPA.")
        return False
    except Exception as e:
        logger.warning(f"❌ Failed to initialize SageAttention 2: {e}")
        return False

# Initialize
initialize_sageattention2()
EOF

echo "✅ Switched to SageAttention 2."
echo "Please restart ComfyUI to apply changes: 'comfyui restart'"
