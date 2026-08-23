"""Schema-907 source provenance validator."""


def validate_v907(value, label="source_provenance_v907"):
    """Return schema errors for a v907 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 907:
        return [f"{label}.schema_version must be 907"]
    return []
