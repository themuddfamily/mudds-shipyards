"""Schema-650 source provenance validator."""
def validate_v650(value,label="source_provenance_v650"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 650: return [f"{label}.schema_version must be 650"]
    return []
