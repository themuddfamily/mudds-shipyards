"""Schema-584 source provenance validator."""
def validate_v584(value,label="source_provenance_v584"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 584: return [f"{label}.schema_version must be 584"]
    return []
