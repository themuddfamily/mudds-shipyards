class_name NetworkEndpointValidator
extends RefCounted

## Pure direct-connect endpoint validation shared by presentation and transport.
## This helper performs no DNS lookup. Brackets are accepted as UI syntax for
## IPv6, then removed before the address reaches ENet.

const MIN_PORT := 1
const MAX_PORT := 65535
const MAX_HOSTNAME_LENGTH := 253
const MAX_HOSTNAME_LABEL_LENGTH := 63


static func normalize_direct_connect_endpoint(address: Variant, port: Variant) -> Dictionary:
	var address_result := _normalize_address(address)
	if not bool(address_result.get("accepted", false)):
		return address_result
	if typeof(port) != TYPE_INT or int(port) < MIN_PORT or int(port) > MAX_PORT:
		return _rejected(
			&"invalid_port",
			"Port must be between %d and %d." % [MIN_PORT, MAX_PORT]
		)
	return {
		"accepted": true,
		"address": str(address_result.get("address", "")),
		"port": int(port),
	}


static func _normalize_address(address: Variant) -> Dictionary:
	if typeof(address) != TYPE_STRING and typeof(address) != TYPE_STRING_NAME:
		return _invalid_address()
	var raw_address := String(address)
	if _contains_control(raw_address):
		return _invalid_address()
	var normalized := raw_address.strip_edges()
	if normalized.is_empty() or normalized.length() > MAX_HOSTNAME_LENGTH:
		return _invalid_address()
	if _contains_whitespace_or_control(normalized) or normalized.contains("%"):
		return _invalid_address()

	var has_open_bracket := normalized.contains("[")
	var has_close_bracket := normalized.contains("]")
	if has_open_bracket or has_close_bracket:
		if not normalized.begins_with("[") or not normalized.ends_with("]"):
			return _invalid_address()
		if normalized.count("[") != 1 or normalized.count("]") != 1:
			return _invalid_address()
		var bracketed_address := normalized.substr(1, normalized.length() - 2)
		if bracketed_address.is_empty() \
				or not bracketed_address.contains(":") \
				or not bracketed_address.is_valid_ip_address():
			return _invalid_address()
		return {"accepted": true, "address": bracketed_address.to_lower()}

	if normalized.is_valid_ip_address():
		return {"accepted": true, "address": normalized.to_lower()}
	if normalized.contains(":"):
		return _invalid_address()

	return _normalize_hostname(normalized)


static func _normalize_hostname(hostname: String) -> Dictionary:
	var normalized := hostname.to_lower()
	if normalized.ends_with("."):
		normalized = normalized.left(-1)
	if normalized.is_empty() or normalized.length() > MAX_HOSTNAME_LENGTH \
			or normalized.begins_with(".") or normalized.ends_with("."):
		return _invalid_address()

	var digits_and_dots_only := true
	for character_index in normalized.length():
		var codepoint := normalized.unicode_at(character_index)
		var is_digit := codepoint >= 48 and codepoint <= 57
		var is_lowercase_letter := codepoint >= 97 and codepoint <= 122
		if not is_digit and not is_lowercase_letter and codepoint != 45 and codepoint != 46:
			return _invalid_address()
		if not is_digit and codepoint != 46:
			digits_and_dots_only = false
	if digits_and_dots_only:
		return _invalid_address()

	for label in normalized.split(".", true):
		if label.is_empty() or label.length() > MAX_HOSTNAME_LABEL_LENGTH \
				or label.begins_with("-") or label.ends_with("-"):
			return _invalid_address()
	return {"accepted": true, "address": normalized}


static func _contains_whitespace_or_control(value: String) -> bool:
	for character_index in value.length():
		var codepoint := value.unicode_at(character_index)
		if codepoint <= 32 or codepoint == 127:
			return true
	return false


static func _contains_control(value: String) -> bool:
	for character_index in value.length():
		var codepoint := value.unicode_at(character_index)
		if codepoint < 32 or codepoint == 127:
			return true
	return false


static func _invalid_address() -> Dictionary:
	return _rejected(&"invalid_address", "Enter a valid IPv4, IPv6, or host name.")


static func _rejected(status: StringName, message: String) -> Dictionary:
	return {
		"accepted": false,
		"reason": status,
		"status": status,
		"validation_error": message,
		"message": message,
	}
