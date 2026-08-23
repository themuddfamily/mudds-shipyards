"""Schema-880 source provenance validator."""


def validate_v880(value, label="source_provenance_v880"):
    """Return schema errors for a v880 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 880:
        return [f"{label}.schema_version must be 880"]
    return []
