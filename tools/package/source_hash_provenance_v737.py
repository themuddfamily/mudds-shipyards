"""Schema-737 source provenance validator."""
def validate_v737(value,label="source_provenance_v737"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 737: return [f"{label}.schema_version must be 737"]
    return []
