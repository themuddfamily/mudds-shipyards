"""Schema-662 source provenance validator."""
def validate_v662(value,label="source_provenance_v662"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 662: return [f"{label}.schema_version must be 662"]
    return []
