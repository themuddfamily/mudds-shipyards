"""Schema-617 source provenance validator."""
def validate_v617(value,label="source_provenance_v617"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 617: return [f"{label}.schema_version must be 617"]
    return []
