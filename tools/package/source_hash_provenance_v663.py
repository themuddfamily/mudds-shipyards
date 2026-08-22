"""Schema-663 source provenance validator."""
def validate_v663(value,label="source_provenance_v663"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 663: return [f"{label}.schema_version must be 663"]
    return []
