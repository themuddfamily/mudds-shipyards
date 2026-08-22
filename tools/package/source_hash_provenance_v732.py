"""Schema-732 source provenance validator."""
def validate_v732(value,label="source_provenance_v732"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 732: return [f"{label}.schema_version must be 732"]
    return []
