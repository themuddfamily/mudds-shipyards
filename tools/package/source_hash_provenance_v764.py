"""Schema-764 source provenance validator."""
def validate_v764(value,label="source_provenance_v764"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 764: return [f"{label}.schema_version must be 764"]
    return []
