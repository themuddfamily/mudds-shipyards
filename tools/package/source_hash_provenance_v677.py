"""Schema-677 source provenance validator."""
def validate_v677(value,label="source_provenance_v677"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 677: return [f"{label}.schema_version must be 677"]
    return []
