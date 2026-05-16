import os 
import yaml


# agent/tools/payload_loader.py
import os
import yaml

PAYLOADS_PATH = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "../../payloads"
)

def load_payload(category: str, payload_id: str) -> str:
    """
    Load a test payload by category and ID.
    Never expose payload content in the chat — load from file.
    
    Example: load_payload("prompt_injection", "PI-001")
    """
    try:
        filepath = os.path.join(PAYLOADS_PATH, category, f"{payload_id}.yaml")
        with open(filepath, "r") as f:
            data = yaml.safe_load(f)
        return data.get("payload", "PAYLOAD_NOT_FOUND")
    except Exception as e:
        return f"LOAD_ERROR: {str(e)}"
