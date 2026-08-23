"""Schema-807 source provenance validator."""
def validate_v807(value,label="source_provenance_v807"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 807: return [f"{label}.schema_version must be 807"]
    return []
