"""Schema-980 source provenance validator."""


def validate_v980(value, label="source_provenance_v980"):
    """Return schema errors for a v980 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 980:
        return [f"{label}.schema_version must be 980"]
    return []
