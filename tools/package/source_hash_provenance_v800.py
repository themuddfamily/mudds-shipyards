"""Schema-800 source provenance validator."""
def validate_v800(value,label="source_provenance_v800"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 800: return [f"{label}.schema_version must be 800"]
    return []
