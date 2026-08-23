"""Schema-792 source provenance validator."""
def validate_v792(value,label="source_provenance_v792"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 792: return [f"{label}.schema_version must be 792"]
    return []
