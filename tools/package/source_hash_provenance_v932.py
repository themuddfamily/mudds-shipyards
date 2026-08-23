"""Schema-932 source provenance validator."""


def validate_v932(value, label="source_provenance_v932"):
    """Return schema errors for a v932 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 932:
        return [f"{label}.schema_version must be 932"]
    return []
