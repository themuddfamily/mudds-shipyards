"""Schema-831 source provenance validator."""


def validate_v831(value, label="source_provenance_v831"):
    """Return schema errors for a v831 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 831:
        return [f"{label}.schema_version must be 831"]
    return []
