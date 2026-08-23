"""Schema-782 source provenance validator."""
def validate_v782(value,label="source_provenance_v782"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 782: return [f"{label}.schema_version must be 782"]
    return []
