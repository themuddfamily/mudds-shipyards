"""Schema-828 source provenance validator."""


def validate_v828(value, label="source_provenance_v828"):
    """Return schema errors for a v828 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 828:
        return [f"{label}.schema_version must be 828"]
    return []
