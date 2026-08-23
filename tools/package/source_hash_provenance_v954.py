"""Schema-954 source provenance validator."""


def validate_v954(value, label="source_provenance_v954"):
    """Return schema errors for a v954 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 954:
        return [f"{label}.schema_version must be 954"]
    return []
