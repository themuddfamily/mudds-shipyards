"""Schema-784 source provenance validator."""
def validate_v784(value,label="source_provenance_v784"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 784: return [f"{label}.schema_version must be 784"]
    return []
