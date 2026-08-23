"""Schema-832 source provenance validator."""


def validate_v832(value, label="source_provenance_v832"):
    """Return schema errors for a v832 source provenance record."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != 832:
        return [f"{label}.schema_version must be 832"]
    return []
