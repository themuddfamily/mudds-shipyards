"""Schema-659 source provenance validator."""
def validate_v659(value,label="source_provenance_v659"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 659: return [f"{label}.schema_version must be 659"]
    return []
