"""Schema-728 source provenance validator."""
def validate_v728(value,label="source_provenance_v728"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 728: return [f"{label}.schema_version must be 728"]
    return []
