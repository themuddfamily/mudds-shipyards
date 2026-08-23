"""Schema-806 source provenance validator."""
def validate_v806(value,label="source_provenance_v806"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 806: return [f"{label}.schema_version must be 806"]
    return []
