extends SceneTree

const BulwarkScene := preload("res://scenes/ships/bulwark_heavy_gunship.tscn")
const Cargo := preload("res://scripts/ships/cinder_cargo_hauler.gd")
const ShipAudioRigScene := preload("res://scenes/audio/ship_audio_rig.tscn")

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bulwark := BulwarkScene.instantiate() as Node
	root.add_child(bulwark)
	await process_frame
	await process_frame
	_check_perspective_contract(bulwark, "Bulwark")
	root.remove_child(bulwark)
	await process_frame
	root.add_child(bulwark)
	await process_frame
	await process_frame
	_check(bool(bulwark.get_node("ShipPerspectiveAudioAdapter").get_snapshot().attached), "Bulwark perspective adapter re-enters")
	_check(bulwark.get_node("ShipAudioRig").get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Bulwark re-entry resets exterior")
	var cargo := Cargo.new()
	var cargo_rig := ShipAudioRigScene.instantiate() as ShipAudioRig
	cargo.add_child(cargo_rig)
	root.add_child(cargo)
	await process_frame
	await process_frame
	_check_perspective_contract(cargo, "Cinder cargo")
	root.remove_child(cargo)
	await process_frame
	root.add_child(cargo)
	await process_frame
	await process_frame
	_check(bool(cargo.get_ship_perspective_audio_snapshot().attached), "Cinder cargo perspective binding re-enters")
	_check(cargo_rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "Cinder cargo re-entry resets exterior")
	_check(int(cargo_rig.get_performance_report().maximum_simultaneous_voices) == 6, "Cinder cargo preserves six voices")
	bulwark.queue_free()
	cargo.queue_free()
	for failure in _failures:
		push_error(failure)
	print("bulwark_cinder_perspective_audio_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check_perspective_contract(craft: Node, label: String) -> void:
	var rig: ShipAudioRig = craft.get_node("ShipAudioRig") as ShipAudioRig if craft.has_node("ShipAudioRig") else craft.get_ship_audio_rig()
	var adapter := craft.get_node("ShipPerspectiveAudioAdapter") if craft.has_node("ShipPerspectiveAudioAdapter") else null
	var snapshot: Dictionary = adapter.get_snapshot() if adapter != null else craft.get_ship_perspective_audio_snapshot()
	_check(bool(snapshot.attached), "%s composes perspective audio" % label)
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "%s starts exterior" % label)
	craft.set_cockpit_view(true)
	var cockpit: Dictionary = rig.get_perspective_mix_snapshot()
	_check(cockpit.perspective == ShipAudioRig.PERSPECTIVE_COCKPIT and float(cockpit.gain_db) < 0.0, "%s cockpit attenuates resident audio" % label)
	craft.set_cockpit_view(false)
	_check(rig.get_audio_perspective() == ShipAudioRig.PERSPECTIVE_EXTERIOR, "%s chase restores exterior" % label)
	_check(rig.get_audit_report().valid, "%s perspective mix remains auditable" % label)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
