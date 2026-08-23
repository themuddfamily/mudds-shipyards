"""Schema-963 source provenance validator."""


def validate_v963(value, label="source_provenance_v963"):
    """Return schema errors for a v963 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 963:
        return [f"{label}.schema_version must be 963"]
    return []
