"""Schema-754 source provenance validator."""
def validate_v754(value,label="source_provenance_v754"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 754: return [f"{label}.schema_version must be 754"]
    return []
