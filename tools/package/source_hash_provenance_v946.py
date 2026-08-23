"""Schema-946 source provenance validator."""


def validate_v946(value, label="source_provenance_v946"):
    """Return schema errors for a v946 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 946:
        return [f"{label}.schema_version must be 946"]
    return []
