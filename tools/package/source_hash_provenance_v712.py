"""Schema-712 source provenance validator."""
def validate_v712(value,label="source_provenance_v712"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 712: return [f"{label}.schema_version must be 712"]
    return []
