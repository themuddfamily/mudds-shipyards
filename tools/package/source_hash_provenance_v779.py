"""Schema-779 source provenance validator."""
def validate_v779(value,label="source_provenance_v779"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 779: return [f"{label}.schema_version must be 779"]
    return []
