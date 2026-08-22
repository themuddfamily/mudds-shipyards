"""Schema-693 source provenance validator."""
def validate_v693(value,label="source_provenance_v693"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 693: return [f"{label}.schema_version must be 693"]
    return []
