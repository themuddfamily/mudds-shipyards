"""Schema-628 source provenance validator."""
def validate_v628(value,label="source_provenance_v628"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 628: return [f"{label}.schema_version must be 628"]
    return []
