"""Schema-756 source provenance validator."""
def validate_v756(value,label="source_provenance_v756"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 756: return [f"{label}.schema_version must be 756"]
    return []
