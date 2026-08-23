"""Schema-785 source provenance validator."""
def validate_v785(value,label="source_provenance_v785"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 785: return [f"{label}.schema_version must be 785"]
    return []
