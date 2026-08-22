"""Schema-610 source provenance validator."""
def validate_v610(value,label="source_provenance_v610"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 610: return [f"{label}.schema_version must be 610"]
    return []
