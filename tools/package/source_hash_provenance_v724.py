"""Schema-724 source provenance validator."""
def validate_v724(value,label="source_provenance_v724"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 724: return [f"{label}.schema_version must be 724"]
    return []
