extends SceneTree

## HALYARD-DECK-002: the exterior airstair is only honest when the production
## Player can cross its hatch and stand on the connected crew-cabin deck.  This
## is intentionally separate from the broad Halyard suite: it exercises the
## actual capsule, ship collision, occupancy volume, and a detach/re-entry of
## the same production craft.

const HALYARD_SCENE := preload("res://scenes/ships/halyard_crew_transport.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

const HATCH_Z := -4.80
const HATCH_WIDTH := 1.90
const PLAYER_CAPSULE_RADIUS := 0.38
const WALK_FRAMES := 42

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "HalyardAirstairCabinTraversalTestRoot"
	root.add_child(_test_root)
	var craft := HALYARD_SCENE.instantiate() as HalyardCrewTransport
	_check(craft != null, "Halyard scene instantiates")
	if craft == null:
		_finish()
		return
	_test_root.add_child(craft)
	await _settle()

	_test_hatch_geometry(craft)
	await _walk_closed_hatch(craft, "closed hatch blocks the embodied player")
	craft.set_canopy_open(true, 0.0)
	await physics_frame
	_test_hatch_state(craft, true)
	await _walk_airstair_into_cabin(craft, "open hatch admits the embodied player")
	craft.set_canopy_open(false, 0.0)
	await physics_frame
	_test_hatch_state(craft, false)
	await _walk_closed_hatch(craft, "reclosed hatch restores the physical barrier")
	craft.set_canopy_open(true, 0.0)
	await physics_frame

	# Re-enter the same production instance.  The split hull must survive a real
	# detach/re-entry, not just initial construction.
	_test_root.remove_child(craft)
	await process_frame
	_test_root.add_child(craft)
	await _settle()
	_test_hatch_geometry(craft)
	_test_hatch_state(craft, true)
	await _walk_airstair_into_cabin(craft, "open hatch remains traversable after detach/re-entry")

	craft.queue_free()
	await process_frame
	_finish()


func _test_hatch_geometry(craft: HalyardCrewTransport) -> void:
	var forward_wall := craft.get_node_or_null("PortHullWallForwardCollision") as CollisionShape3D
	var aft_wall := craft.get_node_or_null("PortHullWallAftCollision") as CollisionShape3D
	_check(forward_wall != null and aft_wall != null, "port hull keeps two fall-protection wall segments around the hatch")
	_check(craft.get_node_or_null("PortHullWallCollision") == null, "the former continuous port wall cannot seal the hatch")
	if forward_wall == null or aft_wall == null:
		return
	var forward_box := forward_wall.shape as BoxShape3D
	var aft_box := aft_wall.shape as BoxShape3D
	_check(forward_box != null and aft_box != null, "both retained port wall segments remain physical box colliders")
	if forward_box == null or aft_box == null:
		return
	var aperture_min := forward_wall.position.z + forward_box.size.z * 0.5
	var aperture_max := aft_wall.position.z - aft_box.size.z * 0.5
	var aperture_width := aperture_max - aperture_min
	_check(is_equal_approx(aperture_min, HATCH_Z - HATCH_WIDTH * 0.5) and is_equal_approx(aperture_max, HATCH_Z + HATCH_WIDTH * 0.5), "physical port-wall aperture stays aligned to the visible airstair hatch")
	_check(is_equal_approx(aperture_width, HATCH_WIDTH), "physical hatch aperture preserves its exact 1.90 m width")
	_check(aperture_width - PLAYER_CAPSULE_RADIUS * 2.0 >= 1.14, "hatch leaves 1.14 m lateral clearance beyond the production capsule diameter")
	_check(forward_box.size.z > 4.0 and aft_box.size.z > 12.0, "substantial hull-wall support remains on both exterior sides of the hatch")
	var blocker := craft.get_node_or_null("PortHatchDoorCollision") as CollisionShape3D
	_check(blocker != null and blocker.shape is BoxShape3D, "the visible port hatch owns one matching physical blocker")
	if blocker != null and blocker.shape is BoxShape3D:
		var blocker_box := blocker.shape as BoxShape3D
		_check(blocker_box.size.is_equal_approx(Vector3(0.14, 2.00, 1.80)), "hatch blocker matches the visible door leaf instead of resealing the whole hull wall")
	for aperture_path in [
		^"HalyardTransportVisual/AirstairHatchSurround",
		^"HalyardTransportVisual/HullCore",
		^"HalyardTransportVisual/PortWindowFrame",
		^"HalyardTransportVisual/PortWindowSill",
		^"HalyardTransportVisual/PortIdentificationBand",
		^"WalkableInterior/CrewCabin/PortCabinSidewall",
	]:
		var aperture_skin := craft.get_node_or_null(aperture_path) as MeshInstance3D
		var aperture_size: Vector2 = aperture_skin.get_meta(&"aperture_size", Vector2.ZERO) \
			if aperture_skin != null else Vector2.ZERO
		_check(
			aperture_skin != null
				and bool(aperture_skin.get_meta(&"port_hatch_aperture", false))
				and aperture_size.y >= HATCH_WIDTH - 0.001,
			"%s carries the aligned closed visual aperture" % aperture_path
		)


func _test_hatch_state(craft: HalyardCrewTransport, open: bool) -> void:
	var door := craft.get_node_or_null("WalkableInterior/CrewCabin/PortHatchDoor") as MeshInstance3D
	var seal := craft.get_node_or_null("WalkableInterior/CrewCabin/PortHatchDoorSeal") as MeshInstance3D
	var blocker := craft.get_node_or_null("PortHatchDoorCollision") as CollisionShape3D
	_check(door != null and seal != null and blocker != null, "port hatch visual and physical nodes resolve")
	if door == null or seal == null or blocker == null:
		return
	var expected_z := HATCH_Z + (2.0 if open else 0.0)
	_check(is_equal_approx(door.position.z, expected_z), "%s hatch door occupies its authored endpoint" % ("open" if open else "closed"))
	_check(is_equal_approx(seal.position.z, expected_z), "%s hatch seal follows the door" % ("open" if open else "closed"))
	_check(blocker.position.is_equal_approx(door.position), "%s hatch blocker stays aligned to the visible door" % ("open" if open else "closed"))
	if open:
		var blocker_box := blocker.shape as BoxShape3D
		var blocker_min_z := blocker.position.z - blocker_box.size.z * 0.5
		_check(blocker_min_z > HATCH_Z + HATCH_WIDTH * 0.5, "fully open hatch clears the complete 1.90 m walking aperture")


func _walk_airstair_into_cabin(craft: HalyardCrewTransport, label: String) -> void:
	var access := craft.get_interior_access_marker()
	var deck := craft.get_interior_deck_marker()
	_check(access != null and deck != null, "%s: route markers resolve" % label)
	if access == null or deck == null:
		return
	var player := PLAYER_SCENE.instantiate() as PlayerController
	_test_root.add_child(player)
	player.set_camera_active(false)
	var camera_yaw := player.get_node_or_null("CameraRig/CameraYaw") as Node3D
	_check(camera_yaw != null, "%s: player camera yaw resolves" % label)
	if camera_yaw != null:
		camera_yaw.rotation.y = 0.0
	# The marker is at the foot of the stair; begin one capsule-safe step onto its
	# sloped collider rather than spawning inside the exterior hull.
	player.teleport_to(Transform3D(Basis.IDENTITY, craft.to_global(access.position + Vector3(0.37, 0.28, 0.0))))
	for _frame in 12:
		await physics_frame
	_check(player.is_on_floor(), "%s: player grounds on the physical airstair" % label)
	Input.action_press("move_right")
	for _frame in WALK_FRAMES:
		await physics_frame
	Input.action_release("move_right")
	# The occupancy Area rebinds deferred after a retained ship re-enters the
	# tree; give that production lifecycle one bounded frame to observe the cabin
	# overlap before asserting registration.
	await process_frame
	await physics_frame
	var local_position := craft.to_local(player.global_position)
	_check(local_position.x > -2.10 and absf(local_position.z - HATCH_Z) < 0.35, "%s: player crosses the hatch into the crew-cabin side" % label)
	_check(player.is_on_floor(), "%s: player remains grounded on the ship-owned cabin deck" % label)
	_check(craft.get_interior_bounds().has_point(local_position), "%s: cabin arrival stays within the published interior bounds" % label)
	_check(craft.get_moving_interior_component().is_occupant_registered(player), "%s: cabin arrival registers with the moving interior" % label)
	player.queue_free()
	await process_frame
	Input.action_release("move_right")


func _walk_closed_hatch(craft: HalyardCrewTransport, label: String) -> void:
	var access := craft.get_interior_access_marker()
	var player := PLAYER_SCENE.instantiate() as PlayerController
	_test_root.add_child(player)
	player.set_camera_active(false)
	var camera_yaw := player.get_node_or_null("CameraRig/CameraYaw") as Node3D
	if camera_yaw != null:
		camera_yaw.rotation.y = 0.0
	player.teleport_to(Transform3D(Basis.IDENTITY, craft.to_global(access.position + Vector3(0.37, 0.28, 0.0))))
	for _frame in 12:
		await physics_frame
	Input.action_press("move_right")
	for _frame in WALK_FRAMES:
		await physics_frame
	Input.action_release("move_right")
	var local_position := craft.to_local(player.global_position)
	_check(local_position.x < -2.62, "%s: player remains outside the pressure hull" % label)
	player.queue_free()
	await process_frame
	Input.action_release("move_right")


func _settle() -> void:
	await process_frame
	await physics_frame
	await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("HALYARD_AIRSTAIR_CABIN_TRAVERSAL_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	quit(1)
