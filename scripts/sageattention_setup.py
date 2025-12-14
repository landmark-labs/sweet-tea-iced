import logging
import torch
import atexit

logger = logging.getLogger(__name__)

# simple counters so you can confirm usage in logs
_used = 0
_fallback = 0

def initialize_sageattention():
    """
    Install a wrapper around PyTorch SDPA.
    We lazily import SageAttention on first GPU half/bfloat16 call.
    If anything fails, we fall back to vanilla SDPA.
    """
    original_sdpa = torch.nn.functional.scaled_dot_product_attention

    def sage_wrapper(q, k, v, attn_mask=None, dropout_p=0.0, is_causal=False, scale=None):
        global _used, _fallback
        try:
            # Only attempt on CUDA half/bfloat16 tensors
            if not (torch.cuda.is_available() and q.is_cuda and q.dtype in (torch.float16, torch.bfloat16)):
                _fallback += 1
                return original_sdpa(q, k, v, attn_mask=attn_mask, dropout_p=dropout_p, is_causal=is_causal, scale=scale)

            major, _ = torch.cuda.get_device_capability()
            if major < 8:
                _fallback += 1
                logger.info(f"SageAttention skipped (compute capability {major}.x < 8.0).")
                return original_sdpa(q, k, v, attn_mask=attn_mask, dropout_p=dropout_p, is_causal=is_causal, scale=scale)

            # Lazy import: this is where Triton may compile small helpers.
            from sageattention import sageattn
            _used += 1
            return sageattn(q, k, v, attn_mask=attn_mask, dropout_p=dropout_p, is_causal=is_causal, scale=scale)
        except Exception as e:
            _fallback += 1
            logger.info(f"SageAttention unavailable ({e}); falling back to SDPA. ({e})")
            return original_sdpa(q, k, v, attn_mask=attn_mask, dropout_p=dropout_p, is_causal=is_causal, scale=scale)

    torch.nn.functional.scaled_dot_product_attention = sage_wrapper
    logger.info("SageAttention wrapper installed (lazy import).")
    return True

NODE_CLASS_MAPPINGS = {}
NODE_DISPLAY_NAME_MAPPINGS = {}

# Auto-run so ComfyUI gets the wrapper at startup
initialize_sageattention()

@atexit.register
def _report():
    logger.info(f"SageAttention stats: used={_used}, fallback={_fallback}")
