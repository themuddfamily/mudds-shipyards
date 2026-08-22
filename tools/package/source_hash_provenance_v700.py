"""Schema-700 source provenance validator."""
def validate_v700(value,label="source_provenance_v700"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 700: return [f"{label}.schema_version must be 700"]
    return []
