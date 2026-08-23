"""Schema-865 source provenance validator."""


def validate_v865(value, label="source_provenance_v865"):
    """Return schema errors for a v865 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 865:
        return [f"{label}.schema_version must be 865"]
    return []
