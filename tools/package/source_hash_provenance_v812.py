"""Schema-812 source provenance validator."""


def validate_v812(value, label="source_provenance_v812"):
    """Return schema errors for a v812 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 812:
        return [f"{label}.schema_version must be 812"]
    return []
