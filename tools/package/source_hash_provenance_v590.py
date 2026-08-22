"""Schema-590 source provenance validator."""
def validate_v590(value,label="source_provenance_v590"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 590: return [f"{label}.schema_version must be 590"]
    return []
