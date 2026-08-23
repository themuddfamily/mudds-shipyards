"""Schema-901 source provenance validator."""


def validate_v901(value, label="source_provenance_v901"):
    """Return schema errors for a v901 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 901:
        return [f"{label}.schema_version must be 901"]
    return []
