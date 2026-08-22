"""Schema-621 source provenance validator."""
def validate_v621(value,label="source_provenance_v621"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 621: return [f"{label}.schema_version must be 621"]
    return []
