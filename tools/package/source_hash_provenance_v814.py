"""Schema-814 source provenance validator."""


def validate_v814(value, label="source_provenance_v814"):
    """Return schema errors for a v814 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 814:
        return [f"{label}.schema_version must be 814"]
    return []
