"""Schema-893 source provenance validator."""


def validate_v893(value, label="source_provenance_v893"):
    """Return schema errors for a v893 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 893:
        return [f"{label}.schema_version must be 893"]
    return []
