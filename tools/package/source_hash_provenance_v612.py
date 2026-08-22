"""Schema-612 source provenance validator."""
def validate_v612(value,label="source_provenance_v612"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 612: return [f"{label}.schema_version must be 612"]
    return []
