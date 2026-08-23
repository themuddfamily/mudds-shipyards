"""Schema-801 source provenance validator."""
def validate_v801(value,label="source_provenance_v801"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 801: return [f"{label}.schema_version must be 801"]
    return []
