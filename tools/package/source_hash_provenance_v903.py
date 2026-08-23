"""Schema-903 source provenance validator."""


def validate_v903(value, label="source_provenance_v903"):
    """Return schema errors for a v903 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 903:
        return [f"{label}.schema_version must be 903"]
    return []
