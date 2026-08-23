"""Schema-878 source provenance validator."""


def validate_v878(value, label="source_provenance_v878"):
    """Return schema errors for a v878 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 878:
        return [f"{label}.schema_version must be 878"]
    return []
