"""Schema-725 source provenance validator."""
def validate_v725(value,label="source_provenance_v725"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 725: return [f"{label}.schema_version must be 725"]
    return []
