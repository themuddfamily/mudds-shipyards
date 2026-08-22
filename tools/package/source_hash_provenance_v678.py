"""Schema-678 source provenance validator."""
def validate_v678(value,label="source_provenance_v678"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 678: return [f"{label}.schema_version must be 678"]
    return []
