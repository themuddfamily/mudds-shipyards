"""Schema-615 source provenance validator."""
def validate_v615(value,label="source_provenance_v615"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 615: return [f"{label}.schema_version must be 615"]
    return []
