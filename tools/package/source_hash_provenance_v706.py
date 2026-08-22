"""Schema-706 source provenance validator."""
def validate_v706(value,label="source_provenance_v706"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 706: return [f"{label}.schema_version must be 706"]
    return []
