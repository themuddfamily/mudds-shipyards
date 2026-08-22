"""Schema-746 source provenance validator."""
def validate_v746(value,label="source_provenance_v746"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 746: return [f"{label}.schema_version must be 746"]
    return []
