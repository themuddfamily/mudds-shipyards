"""Schema-602 source provenance validator."""
def validate_v602(value,label="source_provenance_v602"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 602: return [f"{label}.schema_version must be 602"]
    return []
