"""Schema-745 source provenance validator."""
def validate_v745(value,label="source_provenance_v745"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 745: return [f"{label}.schema_version must be 745"]
    return []
