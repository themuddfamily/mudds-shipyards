"""Schema-606 source provenance validator."""
def validate_v606(value,label="source_provenance_v606"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 606: return [f"{label}.schema_version must be 606"]
    return []
