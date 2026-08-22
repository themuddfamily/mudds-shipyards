"""Schema-644 source provenance validator."""
def validate_v644(value,label="source_provenance_v644"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 644: return [f"{label}.schema_version must be 644"]
    return []
