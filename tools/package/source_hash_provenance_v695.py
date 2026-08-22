"""Schema-695 source provenance validator."""
def validate_v695(value,label="source_provenance_v695"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 695: return [f"{label}.schema_version must be 695"]
    return []
