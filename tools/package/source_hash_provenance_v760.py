"""Schema-760 source provenance validator."""
def validate_v760(value,label="source_provenance_v760"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 760: return [f"{label}.schema_version must be 760"]
    return []
