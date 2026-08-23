"""Schema-883 source provenance validator."""


def validate_v883(value, label="source_provenance_v883"):
    """Return schema errors for a v883 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 883:
        return [f"{label}.schema_version must be 883"]
    return []
