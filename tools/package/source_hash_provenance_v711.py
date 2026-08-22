"""Schema-711 source provenance validator."""
def validate_v711(value,label="source_provenance_v711"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 711: return [f"{label}.schema_version must be 711"]
    return []
