"""Schema-674 source provenance validator."""
def validate_v674(value,label="source_provenance_v674"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 674: return [f"{label}.schema_version must be 674"]
    return []
