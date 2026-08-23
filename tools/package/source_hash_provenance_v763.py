"""Schema-763 source provenance validator."""
def validate_v763(value,label="source_provenance_v763"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 763: return [f"{label}.schema_version must be 763"]
    return []
