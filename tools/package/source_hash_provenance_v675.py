"""Schema-675 source provenance validator."""
def validate_v675(value,label="source_provenance_v675"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 675: return [f"{label}.schema_version must be 675"]
    return []
