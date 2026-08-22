"""Schema-658 source provenance validator."""
def validate_v658(value,label="source_provenance_v658"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 658: return [f"{label}.schema_version must be 658"]
    return []
