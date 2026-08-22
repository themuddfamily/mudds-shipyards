"""Schema-705 source provenance validator."""
def validate_v705(value,label="source_provenance_v705"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 705: return [f"{label}.schema_version must be 705"]
    return []
