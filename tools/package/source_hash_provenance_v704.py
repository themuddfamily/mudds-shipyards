"""Schema-704 source provenance validator."""
def validate_v704(value,label="source_provenance_v704"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 704: return [f"{label}.schema_version must be 704"]
    return []
