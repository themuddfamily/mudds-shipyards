"""Schema-726 source provenance validator."""
def validate_v726(value,label="source_provenance_v726"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 726: return [f"{label}.schema_version must be 726"]
    return []
