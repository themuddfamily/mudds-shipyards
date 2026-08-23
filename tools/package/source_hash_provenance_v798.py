"""Schema-798 source provenance validator."""
def validate_v798(value,label="source_provenance_v798"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 798: return [f"{label}.schema_version must be 798"]
    return []
