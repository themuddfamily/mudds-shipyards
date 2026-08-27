extends SceneTree

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const Authority := preload("res://scripts/ships/crew_seat_role_authority.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var craft: Node = HALYARD_SCENE.instantiate()
	root.add_child(craft)
	await process_frame
	await physics_frame
	var display: Node = craft.get_crew_status_display()
	_check(
		display != null
			and is_instance_valid(display)
			and display.get_parent().name == "CabinStatusPanel",
		"the Halyard retains one crew status display beneath the authored cabin panel"
	)
	_check(
		display.get_readout_text().contains("ROSTER [DETACHED]"),
		"the retained display starts with a safe empty-crew state"
	)
	var authority := Authority.new(1)
	_check(bool(authority.register_halyard_roster().get("accepted", false)), "the focused authority roster seals")
	_check(bool(craft.attach_crew_role_authority(authority).get("accepted", false)), "the Halyard accepts the focused authority")
	_check(bool(authority.claim(1, 71, &"pilot_avatar", &"pilot_station", Authority.ROLE_PILOT, 1).get("accepted", false)), "the pilot claim is admitted")
	_check(bool(authority.claim(1, 77, &"engineer_avatar", &"crew_port_01", Authority.ROLE_ENGINEER, 1).get("accepted", false)), "the engineer claim is admitted")
	var refreshed: Dictionary = craft.refresh_crew_status_display()
	_check(
		bool(refreshed.get("pilot_ready", false))
			and int(refreshed.get("optional_crew_count", 0)) == 1
			and display.get_readout_text().contains("P [ACTIVE] G [OPEN]")
			and display.get_readout_text().contains("E [ACTIVE] X [OPEN]"),
		"an explicit detached-snapshot refresh drives pilot readiness and optional-role tokens"
	)
	var released: Dictionary = craft.release_crew_role(1, 71, &"pilot_avatar", &"pilot_station", 2, 1)
	_check(bool(released.get("accepted", false)), "the pilot release is admitted")
	_check(
		not display.get_display_snapshot().get("pilot_ready", true)
			and display.get_readout_text().contains("DEPART [WAIT PILOT]"),
		"role detach clears visible departure readiness without polling"
	)
	var generation_before_reentry := int(
		display.get_repair_presentation_snapshot().get("generation", -1)
	)
	craft.call("_set_interior_operational", false)
	_check(
		display.get_readout_text().contains("ROSTER [DETACHED]"),
		"interior shutdown clears the retained presentation"
	)
	craft.call("_set_interior_operational", true)
	_check(
		display.get_readout_text().contains("DEPART [WAIT PILOT]")
			and display.get_display_snapshot().get("optional_crew_count", -1) == 1
			and int(display.get_repair_presentation_snapshot().get("generation", -1))
				> generation_before_reentry
			and display.get_readout_text().contains("IDLE // REPAIR READY"),
		"interior re-entry advances the repair fence and reapplies a clean detached crew snapshot"
	)
	var generation_before_release := int(
		display.get_repair_presentation_snapshot().get("generation", -1)
	)
	var engineer_release: Dictionary = craft.release_crew_role(
		1, 77, &"engineer_avatar", &"crew_port_01", 2, 1
	)
	_check(bool(engineer_release.get("accepted", false)), "the engineer role release is admitted")
	_check(
		int(display.get_repair_presentation_snapshot().get("generation", -1))
			> generation_before_release
			and display.get_readout_text().contains("IDLE // REPAIR READY"),
		"engineer role release clears the physical station and advances its snapshot fence"
	)
	var generation_before_reuse := int(
		display.get_repair_presentation_snapshot().get("generation", -1)
	)
	var reset: Dictionary = craft.reset_for_reuse(Transform3D.IDENTITY)
	_check(bool(reset.get("accepted", false)), "the Halyard reuse reset is admitted")
	_check(
		int(display.get_repair_presentation_snapshot().get("generation", -1))
			> generation_before_reuse
			and display.get_readout_text().contains("IDLE // REPAIR READY"),
		"craft reuse clears the engineer station and advances its repair generation"
	)
	craft.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HALYARD_CREW_STATUS_DISPLAY_INTEGRATION_TEST: %d assertions passed" % _assertions)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	quit(0)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
