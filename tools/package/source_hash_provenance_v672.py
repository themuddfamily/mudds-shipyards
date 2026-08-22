"""Schema-672 source provenance validator."""
def validate_v672(value,label="source_provenance_v672"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 672: return [f"{label}.schema_version must be 672"]
    return []
