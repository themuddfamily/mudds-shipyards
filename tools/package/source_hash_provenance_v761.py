"""Schema-761 source provenance validator."""
def validate_v761(value,label="source_provenance_v761"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 761: return [f"{label}.schema_version must be 761"]
    return []
