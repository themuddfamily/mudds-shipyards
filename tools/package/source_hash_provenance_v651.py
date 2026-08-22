"""Schema-651 source provenance validator."""
def validate_v651(value,label="source_provenance_v651"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 651: return [f"{label}.schema_version must be 651"]
    return []
