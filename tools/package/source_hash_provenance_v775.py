"""Schema-775 source provenance validator."""
def validate_v775(value,label="source_provenance_v775"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 775: return [f"{label}.schema_version must be 775"]
    return []
