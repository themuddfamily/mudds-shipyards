"""Schema-591 source provenance validator."""
def validate_v591(value,label="source_provenance_v591"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 591: return [f"{label}.schema_version must be 591"]
    return []
