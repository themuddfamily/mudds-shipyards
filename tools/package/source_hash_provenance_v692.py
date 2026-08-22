"""Schema-692 source provenance validator."""
def validate_v692(value,label="source_provenance_v692"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 692: return [f"{label}.schema_version must be 692"]
    return []
