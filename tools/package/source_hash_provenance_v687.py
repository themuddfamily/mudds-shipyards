"""Schema-687 source provenance validator."""
def validate_v687(value,label="source_provenance_v687"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 687: return [f"{label}.schema_version must be 687"]
    return []
