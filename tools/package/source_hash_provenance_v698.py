"""Schema-698 source provenance validator."""
def validate_v698(value,label="source_provenance_v698"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 698: return [f"{label}.schema_version must be 698"]
    return []
