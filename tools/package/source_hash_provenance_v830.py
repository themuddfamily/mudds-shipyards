"""Schema-830 source provenance validator."""


def validate_v830(value, label="source_provenance_v830"):
    """Return schema errors for a v830 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 830:
        return [f"{label}.schema_version must be 830"]
    return []
