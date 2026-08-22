"""Schema-664 source provenance validator."""
def validate_v664(value,label="source_provenance_v664"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 664: return [f"{label}.schema_version must be 664"]
    return []
