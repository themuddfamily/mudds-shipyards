"""Schema-829 source provenance validator."""


def validate_v829(value, label="source_provenance_v829"):
    """Return schema errors for a v829 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 829:
        return [f"{label}.schema_version must be 829"]
    return []
