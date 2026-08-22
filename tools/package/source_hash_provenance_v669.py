"""Schema-669 source provenance validator."""
def validate_v669(value,label="source_provenance_v669"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 669: return [f"{label}.schema_version must be 669"]
    return []
