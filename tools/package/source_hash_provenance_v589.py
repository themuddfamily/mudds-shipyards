"""Schema-589 source provenance validator."""
def validate_v589(value,label="source_provenance_v589"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 589: return [f"{label}.schema_version must be 589"]
    return []
