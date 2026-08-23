"""Schema-767 source provenance validator."""
def validate_v767(value,label="source_provenance_v767"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 767: return [f"{label}.schema_version must be 767"]
    return []
