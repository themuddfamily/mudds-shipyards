extends SceneTree

const Adapter := preload("res://scripts/network/network_enet_session_adapter.gd")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var adapter := Adapter.new()
	_check(adapter.get_crew_role_snapshot().role_count == 0, "ENet adapter owns an empty detached crew-role snapshot")
	_check(adapter.accept_crew_role_intent(7, 4, &"avatar_7", &"pilot", 1).status == &"authority_required",
		"client-side code cannot commit crew roles through the adapter")
	_check(adapter.send_crew_role_intent(&"avatar_7", &"pilot", 1).status == &"invalid_role_intent",
		"role intent requires an admitted configured session before transport")
	_check(adapter.get_crew_role_snapshot().policy_version == &"network_crew_role_authority_v1",
		"adapter exposes the authoritative role policy without client mutation")
	_check(adapter.reset_snapshot_jitter(2).accepted and adapter.get_crew_role_snapshot().role_count == 0,
		"migration reset clears crew-role presentation state")
	if _failures.is_empty():
		print("OK: ENet crew role integration (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + description)
