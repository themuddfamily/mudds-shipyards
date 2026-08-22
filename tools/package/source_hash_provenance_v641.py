"""Schema-641 source provenance validator."""
def validate_v641(value,label="source_provenance_v641"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 641: return [f"{label}.schema_version must be 641"]
    return []
