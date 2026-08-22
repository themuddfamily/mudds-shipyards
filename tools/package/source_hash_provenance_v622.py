"""Schema-622 source provenance validator."""
def validate_v622(value,label="source_provenance_v622"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 622: return [f"{label}.schema_version must be 622"]
    return []
