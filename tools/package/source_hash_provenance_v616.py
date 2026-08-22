"""Schema-616 source provenance validator."""
def validate_v616(value,label="source_provenance_v616"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 616: return [f"{label}.schema_version must be 616"]
    return []
