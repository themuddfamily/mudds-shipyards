"""Schema-1004 source provenance validator."""


def validate_v1004(value, label="source_provenance_v1004"):
    """Return schema errors for a v1004 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 1004:
        return [f"{label}.schema_version must be 1004"]
    return []
