"""Schema-636 source provenance validator."""
def validate_v636(value,label="source_provenance_v636"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 636: return [f"{label}.schema_version must be 636"]
    return []
