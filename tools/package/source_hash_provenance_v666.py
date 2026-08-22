"""Schema-666 source provenance validator."""
def validate_v666(value,label="source_provenance_v666"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 666: return [f"{label}.schema_version must be 666"]
    return []
