"""Schema-627 source provenance validator."""
def validate_v627(value,label="source_provenance_v627"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 627: return [f"{label}.schema_version must be 627"]
    return []
