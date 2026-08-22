"""Schema-676 source provenance validator."""
def validate_v676(value,label="source_provenance_v676"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 676: return [f"{label}.schema_version must be 676"]
    return []
