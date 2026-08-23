"""Schema-856 source provenance validator."""


def validate_v856(value, label="source_provenance_v856"):
    """Return schema errors for a v856 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 856:
        return [f"{label}.schema_version must be 856"]
    return []
