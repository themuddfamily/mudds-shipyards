"""Schema-696 source provenance validator."""
def validate_v696(value,label="source_provenance_v696"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 696: return [f"{label}.schema_version must be 696"]
    return []
