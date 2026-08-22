"""Schema-686 source provenance validator."""
def validate_v686(value,label="source_provenance_v686"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 686: return [f"{label}.schema_version must be 686"]
    return []
