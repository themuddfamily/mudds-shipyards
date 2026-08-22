"""Schema-625 source provenance validator."""
def validate_v625(value,label="source_provenance_v625"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 625: return [f"{label}.schema_version must be 625"]
    return []
