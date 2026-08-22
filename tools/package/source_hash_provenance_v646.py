"""Schema-646 source provenance validator."""
def validate_v646(value,label="source_provenance_v646"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 646: return [f"{label}.schema_version must be 646"]
    return []
