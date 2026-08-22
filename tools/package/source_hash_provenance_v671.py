"""Schema-671 source provenance validator."""
def validate_v671(value,label="source_provenance_v671"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 671: return [f"{label}.schema_version must be 671"]
    return []
