"""Schema-603 source provenance validator."""
def validate_v603(value,label="source_provenance_v603"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 603: return [f"{label}.schema_version must be 603"]
    return []
