"""Schema-730 source provenance validator."""
def validate_v730(value,label="source_provenance_v730"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 730: return [f"{label}.schema_version must be 730"]
    return []
