"""Schema-624 source provenance validator."""
def validate_v624(value,label="source_provenance_v624"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 624: return [f"{label}.schema_version must be 624"]
    return []
