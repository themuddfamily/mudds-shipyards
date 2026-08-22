"""Schema-718 source provenance validator."""
def validate_v718(value,label="source_provenance_v718"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 718: return [f"{label}.schema_version must be 718"]
    return []
