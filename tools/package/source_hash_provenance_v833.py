"""Schema-833 source provenance validator."""


def validate_v833(value, label="source_provenance_v833"):
    """Return schema errors for a v833 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 833:
        return [f"{label}.schema_version must be 833"]
    return []
