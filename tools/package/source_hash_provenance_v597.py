"""Schema-597 source provenance validator."""
def validate_v597(value,label="source_provenance_v597"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 597: return [f"{label}.schema_version must be 597"]
    return []
