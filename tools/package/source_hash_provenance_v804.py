"""Schema-804 source provenance validator."""
def validate_v804(value,label="source_provenance_v804"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 804: return [f"{label}.schema_version must be 804"]
    return []
