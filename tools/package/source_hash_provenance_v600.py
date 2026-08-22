"""Schema-600 source provenance validator."""
def validate_v600(value,label="source_provenance_v600"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 600: return [f"{label}.schema_version must be 600"]
    return []
