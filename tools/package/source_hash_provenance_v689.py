"""Schema-689 source provenance validator."""
def validate_v689(value,label="source_provenance_v689"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 689: return [f"{label}.schema_version must be 689"]
    return []
