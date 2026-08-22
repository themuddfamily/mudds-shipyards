"""Schema-640 source provenance validator."""
def validate_v640(value,label="source_provenance_v640"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 640: return [f"{label}.schema_version must be 640"]
    return []
