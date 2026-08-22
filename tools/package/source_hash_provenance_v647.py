"""Schema-647 source provenance validator."""
def validate_v647(value,label="source_provenance_v647"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 647: return [f"{label}.schema_version must be 647"]
    return []
