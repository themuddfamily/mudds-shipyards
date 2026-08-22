"""Schema-710 source provenance validator."""
def validate_v710(value,label="source_provenance_v710"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 710: return [f"{label}.schema_version must be 710"]
    return []
