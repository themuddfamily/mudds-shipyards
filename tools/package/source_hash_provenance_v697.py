"""Schema-697 source provenance validator."""
def validate_v697(value,label="source_provenance_v697"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 697: return [f"{label}.schema_version must be 697"]
    return []
