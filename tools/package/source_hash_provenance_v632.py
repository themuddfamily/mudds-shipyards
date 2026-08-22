"""Schema-632 source provenance validator."""
def validate_v632(value,label="source_provenance_v632"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 632: return [f"{label}.schema_version must be 632"]
    return []
