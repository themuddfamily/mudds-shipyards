"""Schema-631 source provenance validator."""
def validate_v631(value,label="source_provenance_v631"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 631: return [f"{label}.schema_version must be 631"]
    return []
