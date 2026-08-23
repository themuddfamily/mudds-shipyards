"""Schema-793 source provenance validator."""
def validate_v793(value,label="source_provenance_v793"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 793: return [f"{label}.schema_version must be 793"]
    return []
