"""Schema-713 source provenance validator."""
def validate_v713(value,label="source_provenance_v713"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 713: return [f"{label}.schema_version must be 713"]
    return []
