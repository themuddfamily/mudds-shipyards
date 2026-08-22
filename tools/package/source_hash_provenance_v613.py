"""Schema-613 source provenance validator."""
def validate_v613(value,label="source_provenance_v613"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 613: return [f"{label}.schema_version must be 613"]
    return []
