"""Schema-744 source provenance validator."""
def validate_v744(value,label="source_provenance_v744"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 744: return [f"{label}.schema_version must be 744"]
    return []
