"""Schema-786 source provenance validator."""
def validate_v786(value,label="source_provenance_v786"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 786: return [f"{label}.schema_version must be 786"]
    return []
