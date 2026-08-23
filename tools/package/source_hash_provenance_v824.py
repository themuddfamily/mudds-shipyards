"""Schema-824 source provenance validator."""


def validate_v824(value, label="source_provenance_v824"):
    """Return schema errors for a v824 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 824:
        return [f"{label}.schema_version must be 824"]
    return []
