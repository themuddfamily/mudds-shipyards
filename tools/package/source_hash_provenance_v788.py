"""Schema-788 source provenance validator."""
def validate_v788(value,label="source_provenance_v788"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 788: return [f"{label}.schema_version must be 788"]
    return []
