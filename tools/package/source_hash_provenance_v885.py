"""Schema-885 source provenance validator."""


def validate_v885(value, label="source_provenance_v885"):
    """Return schema errors for a v885 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 885:
        return [f"{label}.schema_version must be 885"]
    return []
