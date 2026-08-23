"""Schema-752 source provenance validator."""
def validate_v752(value,label="source_provenance_v752"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 752: return [f"{label}.schema_version must be 752"]
    return []
