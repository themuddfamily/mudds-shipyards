"""Schema-742 source provenance validator."""
def validate_v742(value,label="source_provenance_v742"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 742: return [f"{label}.schema_version must be 742"]
    return []
