"""Schema-795 source provenance validator."""
def validate_v795(value,label="source_provenance_v795"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 795: return [f"{label}.schema_version must be 795"]
    return []
