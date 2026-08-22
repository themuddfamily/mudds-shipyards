"""Schema-740 source provenance validator."""
def validate_v740(value,label="source_provenance_v740"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 740: return [f"{label}.schema_version must be 740"]
    return []
