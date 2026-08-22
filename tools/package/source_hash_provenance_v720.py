"""Schema-720 source provenance validator."""
def validate_v720(value,label="source_provenance_v720"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 720: return [f"{label}.schema_version must be 720"]
    return []
