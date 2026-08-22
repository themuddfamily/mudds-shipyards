"""Schema-661 source provenance validator."""
def validate_v661(value,label="source_provenance_v661"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 661: return [f"{label}.schema_version must be 661"]
    return []
