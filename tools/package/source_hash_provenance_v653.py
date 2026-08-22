"""Schema-653 source provenance validator."""
def validate_v653(value,label="source_provenance_v653"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 653: return [f"{label}.schema_version must be 653"]
    return []
