"""Schema-685 source provenance validator."""
def validate_v685(value,label="source_provenance_v685"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 685: return [f"{label}.schema_version must be 685"]
    return []
