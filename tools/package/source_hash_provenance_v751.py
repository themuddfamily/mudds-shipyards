"""Schema-751 source provenance validator."""
def validate_v751(value,label="source_provenance_v751"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 751: return [f"{label}.schema_version must be 751"]
    return []
