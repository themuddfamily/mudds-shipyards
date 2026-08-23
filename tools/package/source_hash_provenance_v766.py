"""Schema-766 source provenance validator."""
def validate_v766(value,label="source_provenance_v766"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 766: return [f"{label}.schema_version must be 766"]
    return []
