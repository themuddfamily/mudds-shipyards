"""Schema-673 source provenance validator."""
def validate_v673(value,label="source_provenance_v673"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 673: return [f"{label}.schema_version must be 673"]
    return []
