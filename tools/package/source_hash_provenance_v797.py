"""Schema-797 source provenance validator."""
def validate_v797(value,label="source_provenance_v797"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 797: return [f"{label}.schema_version must be 797"]
    return []
