"""Schema-731 source provenance validator."""
def validate_v731(value,label="source_provenance_v731"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 731: return [f"{label}.schema_version must be 731"]
    return []
