"""Schema-905 source provenance validator."""


def validate_v905(value, label="source_provenance_v905"):
    """Return schema errors for a v905 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 905:
        return [f"{label}.schema_version must be 905"]
    return []
