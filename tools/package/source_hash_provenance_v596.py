"""Schema-596 source provenance validator."""
def validate_v596(value,label="source_provenance_v596"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 596: return [f"{label}.schema_version must be 596"]
    return []
