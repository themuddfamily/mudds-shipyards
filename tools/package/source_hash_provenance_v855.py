"""Schema-855 source provenance validator."""


def validate_v855(value, label="source_provenance_v855"):
    """Return schema errors for a v855 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 855:
        return [f"{label}.schema_version must be 855"]
    return []
