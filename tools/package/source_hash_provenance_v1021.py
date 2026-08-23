"""Schema-1021 source provenance validator."""


def validate_v1021(value, label="source_provenance_v1021"):
    """Return schema errors for a v1021 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1021:
        return [f"{label}.schema_version must be 1021"]
    return []
