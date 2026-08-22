"""Schema-722 source provenance validator."""
def validate_v722(value,label="source_provenance_v722"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 722: return [f"{label}.schema_version must be 722"]
    return []
