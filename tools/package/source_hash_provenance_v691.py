"""Schema-691 source provenance validator."""
def validate_v691(value,label="source_provenance_v691"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 691: return [f"{label}.schema_version must be 691"]
    return []
