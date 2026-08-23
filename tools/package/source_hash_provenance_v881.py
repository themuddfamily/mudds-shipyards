"""Schema-881 source provenance validator."""


def validate_v881(value, label="source_provenance_v881"):
    """Return schema errors for a v881 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 881:
        return [f"{label}.schema_version must be 881"]
    return []
