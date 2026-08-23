"""Schema-873 source provenance validator."""


def validate_v873(value, label="source_provenance_v873"):
    """Return schema errors for a v873 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 873:
        return [f"{label}.schema_version must be 873"]
    return []
