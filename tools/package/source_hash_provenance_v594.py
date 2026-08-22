"""Schema-594 source provenance validator."""
def validate_v594(value,label="source_provenance_v594"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 594: return [f"{label}.schema_version must be 594"]
    return []
