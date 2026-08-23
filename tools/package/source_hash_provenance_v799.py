"""Schema-799 source provenance validator."""
def validate_v799(value,label="source_provenance_v799"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 799: return [f"{label}.schema_version must be 799"]
    return []
