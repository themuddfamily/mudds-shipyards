"""Schema-966 source provenance validator."""


def validate_v966(value, label="source_provenance_v966"):
    """Return schema errors for a v966 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 966:
        return [f"{label}.schema_version must be 966"]
    return []
