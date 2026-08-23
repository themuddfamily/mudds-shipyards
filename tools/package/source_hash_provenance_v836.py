"""Schema-836 source provenance validator."""


def validate_v836(value, label="source_provenance_v836"):
    """Return schema errors for a v836 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 836:
        return [f"{label}.schema_version must be 836"]
    return []
