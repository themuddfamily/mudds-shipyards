"""Schema-611 source provenance validator."""
def validate_v611(value,label="source_provenance_v611"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 611: return [f"{label}.schema_version must be 611"]
    return []
