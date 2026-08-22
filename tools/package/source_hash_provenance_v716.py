"""Schema-716 source provenance validator."""
def validate_v716(value,label="source_provenance_v716"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 716: return [f"{label}.schema_version must be 716"]
    return []
