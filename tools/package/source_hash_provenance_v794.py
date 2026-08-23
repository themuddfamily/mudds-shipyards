"""Schema-794 source provenance validator."""
def validate_v794(value,label="source_provenance_v794"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 794: return [f"{label}.schema_version must be 794"]
    return []
