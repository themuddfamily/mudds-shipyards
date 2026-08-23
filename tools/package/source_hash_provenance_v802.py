"""Schema-802 source provenance validator."""
def validate_v802(value,label="source_provenance_v802"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 802: return [f"{label}.schema_version must be 802"]
    return []
