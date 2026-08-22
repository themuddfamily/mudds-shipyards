"""Schema-727 source provenance validator."""
def validate_v727(value,label="source_provenance_v727"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 727: return [f"{label}.schema_version must be 727"]
    return []
