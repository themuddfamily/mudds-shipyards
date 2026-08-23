"""Schema-770 source provenance validator."""
def validate_v770(value,label="source_provenance_v770"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 770: return [f"{label}.schema_version must be 770"]
    return []
