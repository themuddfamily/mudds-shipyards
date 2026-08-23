"""Schema-791 source provenance validator."""
def validate_v791(value,label="source_provenance_v791"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 791: return [f"{label}.schema_version must be 791"]
    return []
