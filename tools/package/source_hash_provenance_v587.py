"""Schema-587 source provenance validator."""
def validate_v587(value,label="source_provenance_v587"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 587: return [f"{label}.schema_version must be 587"]
    return []
