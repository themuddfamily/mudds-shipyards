"""Schema-935 source provenance validator."""


def validate_v935(value, label="source_provenance_v935"):
    """Return schema errors for a v935 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 935:
        return [f"{label}.schema_version must be 935"]
    return []
