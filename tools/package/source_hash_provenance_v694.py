"""Schema-694 source provenance validator."""
def validate_v694(value,label="source_provenance_v694"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 694: return [f"{label}.schema_version must be 694"]
    return []
