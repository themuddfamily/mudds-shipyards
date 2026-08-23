"""Schema-822 source provenance validator."""


def validate_v822(value, label="source_provenance_v822"):
    """Return schema errors for a v822 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 822:
        return [f"{label}.schema_version must be 822"]
    return []
