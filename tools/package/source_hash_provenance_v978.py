"""Schema-978 source provenance validator."""


def validate_v978(value, label="source_provenance_v978"):
    """Return schema errors for a v978 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 978:
        return [f"{label}.schema_version must be 978"]
    return []
