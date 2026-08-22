"""Schema-635 source provenance validator."""
def validate_v635(value,label="source_provenance_v635"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 635: return [f"{label}.schema_version must be 635"]
    return []
