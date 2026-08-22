"""Schema-609 source provenance validator."""
def validate_v609(value,label="source_provenance_v609"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 609: return [f"{label}.schema_version must be 609"]
    return []
