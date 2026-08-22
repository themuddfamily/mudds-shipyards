"""Schema-747 source provenance validator."""
def validate_v747(value,label="source_provenance_v747"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 747: return [f"{label}.schema_version must be 747"]
    return []
