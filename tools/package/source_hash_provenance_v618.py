"""Schema-618 source provenance validator."""
def validate_v618(value,label="source_provenance_v618"):
    if not isinstance(value,dict): return [f"{label} must be an object"]
    if value.get("schema_version") != 618: return [f"{label}.schema_version must be 618"]
    return []
