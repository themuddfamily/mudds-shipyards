"""Schema-634 source provenance validator."""
def validate_v634(value,label="source_provenance_v634"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 634: return [f"{label}.schema_version must be 634"]
    return []
