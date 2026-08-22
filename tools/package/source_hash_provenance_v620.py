"""Schema-620 source provenance validator."""
def validate_v620(value,label="source_provenance_v620"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 620: return [f"{label}.schema_version must be 620"]
    return []
