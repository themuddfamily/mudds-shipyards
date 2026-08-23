"""Schema-787 source provenance validator."""
def validate_v787(value,label="source_provenance_v787"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 787: return [f"{label}.schema_version must be 787"]
    return []
