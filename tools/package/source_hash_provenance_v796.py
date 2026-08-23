"""Schema-796 source provenance validator."""
def validate_v796(value,label="source_provenance_v796"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 796: return [f"{label}.schema_version must be 796"]
    return []
