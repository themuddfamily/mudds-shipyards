"""Schema-959 source provenance validator."""


def validate_v959(value, label="source_provenance_v959"):
    """Return schema errors for a v959 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 959:
        return [f"{label}.schema_version must be 959"]
    return []
