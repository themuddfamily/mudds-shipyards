"""Schema-605 source provenance validator."""
def validate_v605(value,label="source_provenance_v605"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 605: return [f"{label}.schema_version must be 605"]
    return []
