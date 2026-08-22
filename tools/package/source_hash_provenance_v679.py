"""Schema-679 source provenance validator."""
def validate_v679(value,label="source_provenance_v679"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 679: return [f"{label}.schema_version must be 679"]
    return []
