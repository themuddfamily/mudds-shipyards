"""Schema-608 source provenance validator."""
def validate_v608(value,label="source_provenance_v608"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 608: return [f"{label}.schema_version must be 608"]
    return []
