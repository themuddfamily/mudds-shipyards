"""Schema-723 source provenance validator."""
def validate_v723(value,label="source_provenance_v723"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 723: return [f"{label}.schema_version must be 723"]
    return []
