"""Schema-729 source provenance validator."""
def validate_v729(value,label="source_provenance_v729"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 729: return [f"{label}.schema_version must be 729"]
    return []
