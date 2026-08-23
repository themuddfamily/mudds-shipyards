"""Schema-750 source provenance validator."""
def validate_v750(value,label="source_provenance_v750"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 750: return [f"{label}.schema_version must be 750"]
    return []
