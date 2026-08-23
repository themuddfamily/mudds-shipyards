"""Schema-749 source provenance validator."""
def validate_v749(value,label="source_provenance_v749"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 749: return [f"{label}.schema_version must be 749"]
    return []
