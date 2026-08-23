"""Schema-772 source provenance validator."""
def validate_v772(value,label="source_provenance_v772"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 772: return [f"{label}.schema_version must be 772"]
    return []
