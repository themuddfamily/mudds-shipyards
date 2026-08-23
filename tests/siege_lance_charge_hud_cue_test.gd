extends SceneTree

## Focused production-seam regression for the picket charge caption. The craft
## must arm its existing charge before the retained HUD receives a cue, while
## the live resolver sequence and target health remain untouched.

const PICKET_SCENE := preload("res://scenes/ships/standoff_picket_opponent.tscn")
const TARGET_SCENE := preload("res://scenes/ships/range_opponent.tscn")
const PULSE_SCENE := preload("res://scenes/effects/pulse_weapon_presentation.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const AuthorityType := preload("res://scripts/combat/live_combat_authority.gd")

var _assertions := 0
var _failures := PackedStringArray()
var _caption_requests: Array[Dictionary] = []
var _weapon_records: Array[Dictionary] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var host := Node3D.new()
	host.name = "SiegeLanceChargeCueWorld"
	root.add_child(host)

	var authority := AuthorityType.new() as LiveCombatAuthority
	authority.name = "CombatAuthority"
	host.add_child(authority)
	var pulse := PULSE_SCENE.instantiate() as PulseWeaponPresentation
	pulse.name = "PulseWeaponPresentation"
	host.add_child(pulse)
	var hud := HUD_SCENE.instantiate() as GameHUD
	hud.name = "HUD"
	host.add_child(hud)
	hud.set_captions_enabled(true)
	hud.bind_caption_event_submitter(Callable(self, &"_capture_caption_request"))

	var target := TARGET_SCENE.instantiate() as RangeOpponent
	target.name = "ChargeTarget"
	host.add_child(target)
	target.activate(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -110.0)))
	target.velocity = Vector3.ZERO

	var picket := PICKET_SCENE.instantiate() as StandoffPicketOpponent
	picket.name = "StandoffPicket"
	picket.escort_enabled = false
	picket.acceleration = 0.0
	picket.initial_arming_delay = 0.0
	picket.combat_authority_path = NodePath("../CombatAuthority")
	picket.pulse_presentation_path = NodePath("../PulseWeaponPresentation")
	picket.combat_audio_path = NodePath("../MissingCombatAudio")
	picket.hud_path = NodePath("../HUD")
	host.add_child(picket)
	picket.siege_lance_audio_record.connect(_capture_weapon_record)

	await process_frame
	await physics_frame
	var facing := (target.global_position - Vector3.ZERO).normalized()
	picket.activate(Transform3D(
		Basis.looking_at(facing, Vector3.UP).orthonormalized(),
		Vector3.ZERO,
	))
	picket.set_target(target)
	var resolver := authority.get_resolver() as CombatResolver
	var sequence_before := resolver.get_last_sequence(picket, picket.source_id)
	var health_before := target.get_health()

	var charge_started := await _advance_until(
		func() -> bool:
			return bool(picket.get_lance_charge_snapshot().get("active", false)),
		60,
	)
	var charge := picket.get_lance_charge_snapshot()
	_check(
		charge_started
		and bool(charge.get("armed", false))
		and float(charge.get("remaining", 0.0)) > 0.0
		and _weapon_records.size() == 1
		and _weapon_records[0].get("event_id", &"") == &"charge_started"
		and bool(_weapon_records[0].get("accepted", false)),
		"the real picket charge arms and emits its accepted charge-started weapon record",
	)
	_check(
		_caption_requests.size() == 1
		and str(_caption_requests[0].get("speaker", "")) == "threat_warning"
		and str(_caption_requests[0].get("text", "")).contains("Siege lance charging")
		and str(_caption_requests[0].get("text", "")).begins_with("!")
		and int(_caption_requests[0].get("priority", 0)) >= 90,
		"the retained combat HUD exposes one high-severity textual charge warning",
	)
	_check(
		resolver.get_last_sequence(picket, picket.source_id) == sequence_before
		and is_equal_approx(target.get_health(), health_before),
		"the pre-dispatch caption consumes no resolver sequence and applies no damage",
	)

	host.queue_free()
	await process_frame
	await physics_frame
	await process_frame
	_finish()


func _advance_until(condition: Callable, frame_budget: int) -> bool:
	for _index in frame_budget:
		if bool(condition.call()):
			return true
		await physics_frame
		await process_frame
	return bool(condition.call())


func _capture_caption_request(request: Dictionary) -> bool:
	_caption_requests.append(request.duplicate(true))
	return true


func _capture_weapon_record(record: Dictionary) -> void:
	_weapon_records.append(record.duplicate(true))


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SIEGE_LANCE_CHARGE_HUD_CUE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	print("SIEGE_LANCE_CHARGE_HUD_CUE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
