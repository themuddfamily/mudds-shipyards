"""Schema-655 source provenance validator."""
def validate_v655(value,label="source_provenance_v655"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 655: return [f"{label}.schema_version must be 655"]
    return []
