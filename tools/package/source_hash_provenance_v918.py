"""Schema-918 source provenance validator."""


def validate_v918(value, label="source_provenance_v918"):
    """Return schema errors for a v918 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 918:
        return [f"{label}.schema_version must be 918"]
    return []
