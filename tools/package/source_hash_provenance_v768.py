"""Schema-768 source provenance validator."""
def validate_v768(value,label="source_provenance_v768"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 768: return [f"{label}.schema_version must be 768"]
    return []
