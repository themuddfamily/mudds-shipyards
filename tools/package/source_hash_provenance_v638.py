"""Schema-638 source provenance validator."""
def validate_v638(value,label="source_provenance_v638"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 638: return [f"{label}.schema_version must be 638"]
    return []
