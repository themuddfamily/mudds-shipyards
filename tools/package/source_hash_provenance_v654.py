"""Schema-654 source provenance validator."""
def validate_v654(value,label="source_provenance_v654"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 654: return [f"{label}.schema_version must be 654"]
    return []
