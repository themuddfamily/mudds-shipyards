"""Schema-755 source provenance validator."""
def validate_v755(value,label="source_provenance_v755"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 755: return [f"{label}.schema_version must be 755"]
    return []
