"""Schema-987 source provenance validator."""


def validate_v987(value, label="source_provenance_v987"):
    """Return schema errors for a v987 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 987:
        return [f"{label}.schema_version must be 987"]
    return []
