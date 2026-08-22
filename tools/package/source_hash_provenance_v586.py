"""Schema-586 source provenance validator."""
def validate_v586(value,label="source_provenance_v586"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 586: return [f"{label}.schema_version must be 586"]
    return []
