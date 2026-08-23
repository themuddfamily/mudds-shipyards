extends SceneTree

const Presenter := preload("res://scripts/ui/server_browser_presenter.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := Presenter.new()
	var view := presenter.present_result({"accepted": true, "rows": []})
	_check((view.controls as Array).size() == 2, "host and manual join controls are exposed")
	_check((view.controls as Array)[0].focusable and (view.controls as Array)[1].focusable, "browser controls are controller-focusable")
	var host := presenter.host_session_intent(27101, "Pilot One")
	_check(host.accepted and host.action == &"host_session" and not host.authority, "host emits a caller-owned intent")
	var join := presenter.manual_join_intent("example.test", 27101, "Pilot One")
	_check(join.accepted and join.action == &"manual_join" and join.address == "example.test", "manual join emits a caller-owned intent")
	var bad_port := presenter.manual_join_intent("example.test", 0, "Pilot One")
	_check(not bad_port.accepted and bad_port.reason == &"invalid_port" and bad_port.validation_error is String, "invalid port has readable validation feedback")
	var bad_address := presenter.manual_join_intent("bad address", 27101, "Pilot One")
	_check(not bad_address.accepted and bad_address.reason == &"invalid_address", "invalid address is rejected without networking")
	var ipv6 := presenter.configure_manual_connect("[fe80::1]", 27101, "Pilot One")
	_check(ipv6.accepted and ipv6.form.address == "[fe80::1]" and ipv6.focus_target == &"manual_join", "IPv6-local direct connect is bounded and caller-owned")
	var malformed_ipv6 := presenter.configure_manual_connect("[fe80::1", 27101, "Pilot One")
	_check(not malformed_ipv6.accepted and malformed_ipv6.form.focus_target == &"manual_address" and "IPv6" in malformed_ipv6.form.error, "invalid IPv6 entry returns explicit address focus and error")
	var bad_form_port := presenter.configure_manual_connect("127.0.0.1", 0, "Pilot One")
	_check(not bad_form_port.accepted and bad_form_port.focus_target == &"manual_port" and bad_form_port.form.error is String, "invalid direct-connect port restores port focus with readable feedback")
	_check(presenter.get_manual_connect_view().actions.size() == 2, "manual connect view exposes focusable connect and cancel actions")
	var bad_name := presenter.host_session_intent(27101, "")
	_check(not bad_name.accepted and bad_name.reason == &"invalid_player_name", "missing player name has bounded validation")
	_check(not presenter.manual_join_intent("example.test", 27101, "Pilot One").get("opens_socket", false), "presenter never claims socket authority")
	if _failures.is_empty():
		print("SERVER_BROWSER_MANUAL_CONTROLS_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
