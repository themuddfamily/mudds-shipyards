"""Schema-668 source provenance validator."""
def validate_v668(value,label="source_provenance_v668"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 668: return [f"{label}.schema_version must be 668"]
    return []
