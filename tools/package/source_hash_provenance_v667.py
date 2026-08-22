"""Schema-667 source provenance validator."""
def validate_v667(value,label="source_provenance_v667"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 667: return [f"{label}.schema_version must be 667"]
    return []
