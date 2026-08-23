"""Schema-894 source provenance validator."""


def validate_v894(value, label="source_provenance_v894"):
    """Return schema errors for a v894 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 894:
        return [f"{label}.schema_version must be 894"]
    return []
