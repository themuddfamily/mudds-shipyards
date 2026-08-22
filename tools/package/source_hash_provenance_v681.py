"""Schema-681 source provenance validator."""
def validate_v681(value,label="source_provenance_v681"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 681: return [f"{label}.schema_version must be 681"]
    return []
