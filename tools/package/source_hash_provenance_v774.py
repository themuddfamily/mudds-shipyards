"""Schema-774 source provenance validator."""
def validate_v774(value,label="source_provenance_v774"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 774: return [f"{label}.schema_version must be 774"]
    return []
