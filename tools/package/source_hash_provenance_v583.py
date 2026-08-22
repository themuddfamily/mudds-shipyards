"""Schema-583 source provenance validator."""
def validate_v583(value,label="source_provenance_v583"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 583: return [f"{label}.schema_version must be 583"]
    return []
