"""Schema-738 source provenance validator."""
def validate_v738(value,label="source_provenance_v738"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 738: return [f"{label}.schema_version must be 738"]
    return []
