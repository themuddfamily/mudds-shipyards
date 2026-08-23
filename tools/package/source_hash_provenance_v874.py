"""Schema-874 source provenance validator."""


def validate_v874(value, label="source_provenance_v874"):
    """Return schema errors for a v874 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 874:
        return [f"{label}.schema_version must be 874"]
    return []
