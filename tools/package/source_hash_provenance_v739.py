"""Schema-739 source provenance validator."""
def validate_v739(value,label="source_provenance_v739"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 739: return [f"{label}.schema_version must be 739"]
    return []
