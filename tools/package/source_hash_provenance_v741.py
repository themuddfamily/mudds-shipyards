"""Schema-741 source provenance validator."""
def validate_v741(value,label="source_provenance_v741"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 741: return [f"{label}.schema_version must be 741"]
    return []
