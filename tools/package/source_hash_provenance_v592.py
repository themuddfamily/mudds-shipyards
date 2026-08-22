"""Schema-592 source provenance validator."""
def validate_v592(value,label="source_provenance_v592"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 592: return [f"{label}.schema_version must be 592"]
    return []
