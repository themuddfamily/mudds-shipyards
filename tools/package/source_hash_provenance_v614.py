"""Schema-614 source provenance validator."""
def validate_v614(value,label="source_provenance_v614"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 614: return [f"{label}.schema_version must be 614"]
    return []
