"""Schema-735 source provenance validator."""
def validate_v735(value,label="source_provenance_v735"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 735: return [f"{label}.schema_version must be 735"]
    return []
