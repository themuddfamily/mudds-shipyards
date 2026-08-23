"""Schema-778 source provenance validator."""
def validate_v778(value,label="source_provenance_v778"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 778: return [f"{label}.schema_version must be 778"]
    return []
