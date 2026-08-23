"""Schema-849 source provenance validator."""


def validate_v849(value, label="source_provenance_v849"):
    """Return schema errors for a v849 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 849:
        return [f"{label}.schema_version must be 849"]
    return []
