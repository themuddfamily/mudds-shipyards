"""Schema-758 source provenance validator."""
def validate_v758(value,label="source_provenance_v758"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 758: return [f"{label}.schema_version must be 758"]
    return []
