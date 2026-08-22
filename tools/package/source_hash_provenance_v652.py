"""Schema-652 source provenance validator."""
def validate_v652(value,label="source_provenance_v652"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 652: return [f"{label}.schema_version must be 652"]
    return []
