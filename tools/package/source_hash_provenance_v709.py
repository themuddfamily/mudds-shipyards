"""Schema-709 source provenance validator."""
def validate_v709(value,label="source_provenance_v709"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 709: return [f"{label}.schema_version must be 709"]
    return []
