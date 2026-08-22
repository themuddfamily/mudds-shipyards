"""Schema-626 source provenance validator."""
def validate_v626(value,label="source_provenance_v626"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 626: return [f"{label}.schema_version must be 626"]
    return []
