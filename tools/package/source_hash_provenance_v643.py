"""Schema-643 source provenance validator."""
def validate_v643(value,label="source_provenance_v643"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 643: return [f"{label}.schema_version must be 643"]
    return []
