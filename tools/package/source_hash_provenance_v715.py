"""Schema-715 source provenance validator."""
def validate_v715(value,label="source_provenance_v715"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 715: return [f"{label}.schema_version must be 715"]
    return []
