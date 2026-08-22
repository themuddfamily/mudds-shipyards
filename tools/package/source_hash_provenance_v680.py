"""Schema-680 source provenance validator."""
def validate_v680(value,label="source_provenance_v680"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 680: return [f"{label}.schema_version must be 680"]
    return []
