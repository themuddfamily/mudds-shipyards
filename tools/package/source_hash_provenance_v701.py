"""Schema-701 source provenance validator."""
def validate_v701(value,label="source_provenance_v701"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 701: return [f"{label}.schema_version must be 701"]
    return []
