"""Schema-637 source provenance validator."""
def validate_v637(value,label="source_provenance_v637"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 637: return [f"{label}.schema_version must be 637"]
    return []
