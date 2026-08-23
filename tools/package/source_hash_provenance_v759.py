"""Schema-759 source provenance validator."""
def validate_v759(value,label="source_provenance_v759"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 759: return [f"{label}.schema_version must be 759"]
    return []
