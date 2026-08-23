"""Schema-877 source provenance validator."""


def validate_v877(value, label="source_provenance_v877"):
    """Return schema errors for a v877 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 877:
        return [f"{label}.schema_version must be 877"]
    return []
