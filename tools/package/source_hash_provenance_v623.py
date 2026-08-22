"""Schema-623 source provenance validator."""
def validate_v623(value,label="source_provenance_v623"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 623: return [f"{label}.schema_version must be 623"]
    return []
