"""Schema-904 source provenance validator."""


def validate_v904(value, label="source_provenance_v904"):
    """Return schema errors for a v904 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 904:
        return [f"{label}.schema_version must be 904"]
    return []
