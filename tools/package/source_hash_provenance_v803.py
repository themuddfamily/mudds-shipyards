"""Schema-803 source provenance validator."""
def validate_v803(value,label="source_provenance_v803"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 803: return [f"{label}.schema_version must be 803"]
    return []
