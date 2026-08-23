"""Schema-1022 source provenance validator."""


def validate_v1022(value, label="source_provenance_v1022"):
    """Return schema errors for a v1022 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1022:
        return [f"{label}.schema_version must be 1022"]
    return []
