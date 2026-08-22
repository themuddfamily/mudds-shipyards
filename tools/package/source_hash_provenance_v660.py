"""Schema-660 source provenance validator."""
def validate_v660(value,label="source_provenance_v660"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 660: return [f"{label}.schema_version must be 660"]
    return []
