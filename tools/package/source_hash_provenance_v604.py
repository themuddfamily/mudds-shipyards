"""Schema-604 source provenance validator."""
def validate_v604(value,label="source_provenance_v604"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 604: return [f"{label}.schema_version must be 604"]
    return []
