"""Schema-639 source provenance validator."""
def validate_v639(value,label="source_provenance_v639"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 639: return [f"{label}.schema_version must be 639"]
    return []
