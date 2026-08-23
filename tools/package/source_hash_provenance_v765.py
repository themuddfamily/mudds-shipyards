"""Schema-765 source provenance validator."""
def validate_v765(value,label="source_provenance_v765"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 765: return [f"{label}.schema_version must be 765"]
    return []
