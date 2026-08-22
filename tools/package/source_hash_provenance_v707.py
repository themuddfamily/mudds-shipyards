"""Schema-707 source provenance validator."""
def validate_v707(value,label="source_provenance_v707"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 707: return [f"{label}.schema_version must be 707"]
    return []
