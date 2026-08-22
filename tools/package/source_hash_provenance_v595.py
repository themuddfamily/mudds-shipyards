"""Schema-595 source provenance validator."""
def validate_v595(value,label="source_provenance_v595"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 595: return [f"{label}.schema_version must be 595"]
    return []
