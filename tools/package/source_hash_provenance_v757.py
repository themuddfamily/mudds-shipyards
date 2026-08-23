"""Schema-757 source provenance validator."""
def validate_v757(value,label="source_provenance_v757"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 757: return [f"{label}.schema_version must be 757"]
    return []
