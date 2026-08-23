"""Schema-771 source provenance validator."""
def validate_v771(value,label="source_provenance_v771"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 771: return [f"{label}.schema_version must be 771"]
    return []
