"""Schema-734 source provenance validator."""
def validate_v734(value,label="source_provenance_v734"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 734: return [f"{label}.schema_version must be 734"]
    return []
