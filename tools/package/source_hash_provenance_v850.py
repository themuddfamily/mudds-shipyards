"""Schema-850 source provenance validator."""


def validate_v850(value, label="source_provenance_v850"):
    """Return schema errors for a v850 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 850:
        return [f"{label}.schema_version must be 850"]
    return []
