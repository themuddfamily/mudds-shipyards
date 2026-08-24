extends SceneTree

const Validator := preload("res://scripts/network/network_endpoint_validator.gd")
const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var valid_cases := [
		[" example.test ", 27101, "example.test"],
		["EXAMPLE.TEST.", 65535, "example.test"],
		["localhost", 1, "localhost"],
		["192.0.2.24", 27101, "192.0.2.24"],
		["2001:DB8::7", 27101, "2001:db8::7"],
		["[2001:DB8::7]", 27101, "2001:db8::7"],
	]
	for test_case in valid_cases:
		var result := Validator.normalize_direct_connect_endpoint(test_case[0], test_case[1])
		_check(
			bool(result.get("accepted", false))
				and str(result.get("address", "")) == test_case[2]
				and int(result.get("port", 0)) == test_case[1],
			"valid endpoint normalizes for transport: %s" % test_case[0]
		)

	var invalid_addresses := [
		"", "[]", "[127.0.0.1]", "[2001:db8::7", "2001:db8::7]",
		"[2001:db8::7]:27101", "example.test:27101", "fe80::1%eth0",
		"[fe80::1%25eth0]", "bad host", "bad_host", "-bad.test",
		"bad-.test", "bad..test", "999.1.1.1", "café.test",
	]
	for address in invalid_addresses:
		var result := Validator.normalize_direct_connect_endpoint(address, 27101)
		_check(
			not bool(result.get("accepted", false)) and result.get("status", &"") == &"invalid_address",
			"invalid address is rejected without DNS or transport: %s" % address
		)

	for port in [0, 65536, -1, "27101", 27101.0, null]:
		var result := Validator.normalize_direct_connect_endpoint("example.test", port)
		_check(
			not bool(result.get("accepted", false)) and result.get("status", &"") == &"invalid_port",
			"invalid or coerced port is rejected: %s" % str(port)
		)

	var adapter := Adapter.new()
	root.add_child(adapter)
	var rejected := adapter.consume_direct_connect_intent({"address": "[]", "port": 27101})
	_check(
		not bool(rejected.get("accepted", false))
			and rejected.get("status", &"") == &"invalid_address"
			and adapter.get("_peer") == null,
		"adapter revalidates an invalid intent before allocating socket authority"
	)
	var joined := adapter.consume_direct_connect_intent({"address": "[::1]", "port": 27101})
	_check(
		bool(joined.get("accepted", false)) and joined.get("address", "") == "::1",
		"adapter strips IPv6 brackets before handing the endpoint to ENet"
	)
	if bool(joined.get("accepted", false)):
		adapter.shutdown(&"test_cleanup")
	adapter.free()

	if _failures.is_empty():
		print("NETWORK_ENDPOINT_VALIDATOR_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
