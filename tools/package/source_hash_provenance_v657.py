"""Schema-657 source provenance validator."""
def validate_v657(value,label="source_provenance_v657"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 657: return [f"{label}.schema_version must be 657"]
    return []
