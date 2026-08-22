"""Schema-619 source provenance validator."""
def validate_v619(value,label="source_provenance_v619"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 619: return [f"{label}.schema_version must be 619"]
    return []
