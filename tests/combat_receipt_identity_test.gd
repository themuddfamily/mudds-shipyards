extends SceneTree

const CombatAuthority := preload("res://scripts/combat/live_combat_authority.gd")
const DamageableType := preload("res://scripts/combat/damageable.gd")
const ShotRequestType := preload("res://scripts/combat/shot_request.gd")

const WEAPON_ID := &"receipt_tester"
const PRIMARY_SOURCE_ID := 9101
const BASE_DAMAGE := 1.0
const BASE_RANGE := 220.0
const HIGH_SOURCE_ID_A := (1 << 31)
const HIGH_SOURCE_ID_B := (1 << 31) + 1
const TWO_TO_THE_32 := 4294967296
const ALIASED_SOURCE_ID := PRIMARY_SOURCE_ID + TWO_TO_THE_32
const INT64_MAX := 9223372036854775807
const SOURCE_A_POSITION := Vector3(-24.0, 0.0, 0.0)

const TEST_WEAPON_PROFILES := {
	WEAPON_ID: {
		"range": BASE_RANGE,
		"damage": BASE_DAMAGE,
		"origin_tolerance": 4.0,
	},
}

var _failures: Array[String] = []
var _assertions := 0
var _captured_requests: Array[ShotRequestType] = []
var _captured_results: Array[Dictionary] = []


class ReceiptTrackingDamageable:
	extends DamageableType

	var _pending_receipts: Dictionary = {}

	func apply_damage(
		amount: float,
		hit_position: Vector3 = Vector3.INF,
		hit_normal: Vector3 = Vector3.ZERO,
		source_context: Dictionary = {}
	) -> Dictionary:
		var result := super.apply_damage(amount, hit_position, hit_normal, source_context)
		var receipt_id := int(source_context.get("presentation_receipt_id", -1))
		if result.get("accepted", false) and receipt_id >= 0:
			_pending_receipts[receipt_id] = true
		return result

	func commit_deferred_damage_presentation(receipt_id: int) -> bool:
		if not _pending_receipts.has(receipt_id):
			return false
		_pending_receipts.erase(receipt_id)
		return true

	func has_pending_receipt(receipt_id: int) -> bool:
		return _pending_receipts.has(receipt_id)

	func get_pending_receipt_count() -> int:
		return _pending_receipts.size()


class ReceiptTarget:
	extends StaticBody3D

	var damageable: ReceiptTrackingDamageable

	func _init() -> void:
		name = "ReceiptTarget"
		damageable = ReceiptTrackingDamageable.new()
		damageable.name = "ReceiptDamageable"
		add_child(damageable)

		var shape_root := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 1.0
		shape_root.shape = shape
		add_child(shape_root)

	func _ready() -> void:
		collision_layer = 1 << 2

	func commit_deferred_damage_presentation(receipt_id: int) -> bool:
		return damageable.commit_deferred_damage_presentation(receipt_id)

	func has_pending_receipt(receipt_id: int) -> bool:
		return damageable.has_pending_receipt(receipt_id)

	func get_pending_receipt_count() -> int:
		return damageable.get_pending_receipt_count()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_root_child_count := root.get_child_count()
	var authority := _build_authority_fixture()
	var authority_holder := authority.get_parent()
	var source := _make_node("PrimarySource", SOURCE_A_POSITION)
	var high_source_a := _make_node("HighSourceA", Vector3(0.0, 20.0, 6.0))
	var high_source_b := _make_node("HighSourceB", Vector3(0.0, 24.0, -6.0))
	var target_a := _make_target("TargetA", Vector3(20.0, 0.0, 0.0))
	var target_b := _make_target("TargetB", Vector3(46.0, 10.0, 0.0))
	var target_c := _make_target("TargetC", Vector3(72.0, -10.0, 0.0))
	await process_frame
	await physics_frame

	# Retained witnesses for the identity failures in the replaced bit-pack.
	# These make the regression concrete without reintroducing the legacy path to
	# production: signed high source IDs lose positivity, and either a 32-bit
	# source or sequence stride aliases the same receipt.
	_check(
		_legacy_bitpacked_receipt(HIGH_SOURCE_ID_A, 0) <= 0
		and _legacy_bitpacked_receipt(HIGH_SOURCE_ID_B, 0) <= 0,
		"legacy bit-packing cannot keep source IDs at or above 2^31 positive"
	)
	_check(
		_legacy_bitpacked_receipt(PRIMARY_SOURCE_ID, 0)
		== _legacy_bitpacked_receipt(PRIMARY_SOURCE_ID, TWO_TO_THE_32),
		"legacy bit-packing aliases sequences separated by 2^32"
	)
	_check(
		_legacy_bitpacked_receipt(PRIMARY_SOURCE_ID, 0)
		== _legacy_bitpacked_receipt(ALIASED_SOURCE_ID, 0),
		"legacy bit-packing aliases one sequence from sources separated by 2^32"
	)

	var registered: bool = authority.register_source(source, PRIMARY_SOURCE_ID, &"test_force", TEST_WEAPON_PROFILES)
	var high_sources_registered: bool = authority.register_source(high_source_a, HIGH_SOURCE_ID_A, &"test_force", TEST_WEAPON_PROFILES)
	high_sources_registered = high_sources_registered and authority.register_source(high_source_b, HIGH_SOURCE_ID_B, &"test_force", TEST_WEAPON_PROFILES)
	_check(registered and high_sources_registered, "primary and high-id sources register for deferred-combat receipts")

	var shot1 := _shoot(authority, source, target_a)
	var shot2 := _shoot(authority, source, target_b)
	var shot3 := _shoot(authority, source, target_c)
	var shot4 := _shoot(authority, high_source_a, target_a)
	var shot5 := _shoot(authority, high_source_b, target_b)

	var receipt1: int = int(shot1.get("receipt_id", -1))
	var receipt2: int = int(shot2.get("receipt_id", -1))
	var receipt3: int = int(shot3.get("receipt_id", -1))
	var receipt4: int = int(shot4.get("receipt_id", -1))
	var receipt5: int = int(shot5.get("receipt_id", -1))
	_check(receipt1 == 1 and receipt2 == 2 and receipt3 == 3, "session allocator starts at one and increments by one")
	_check(receipt4 == 4 and receipt5 == 5, "receipt allocation is independent of source id/sequence")
	_check(
		receipt1 > 0 and receipt2 > 0 and receipt3 > 0 and receipt4 > 0 and receipt5 > 0,
		"all generated deferred receipts are strictly positive"
	)
	_check(
		receipt1 != receipt2 and receipt2 != receipt3 and receipt1 != receipt3,
		"receipts from sequential shots are unique"
	)
	_check(
		receipt4 != receipt5 and receipt5 != receipt1 and receipt4 != receipt1,
		"multiple sources using the same sequence get distinct receipt IDs"
	)

	# Raise one source sequence ahead of expectation without touching the global
	# allocator and verify ID remains unique.
	var source_a_instance_id: int = source.get_instance_id()
	var sequences := authority.get("_next_sequence_by_instance") as Dictionary
	if sequences is Dictionary:
		sequences = sequences.duplicate(true)
		sequences[source_a_instance_id] = TWO_TO_THE_32
		authority.set("_next_sequence_by_instance", sequences)
	var shot_gap := _shoot(authority, source, target_b)
	var gap_receipt: int = int(shot_gap.get("receipt_id", -1))
	_check(gap_receipt > receipt5, "sequence gaps are reflected in request metadata but not receipt identity")
	var gap_request := shot_gap.get("request") as ShotRequestType
	var gap_result := shot_gap.get("result", {}) as Dictionary
	_check(
		gap_request != null
		and gap_request.source_id == PRIMARY_SOURCE_ID
		and gap_request.sequence == TWO_TO_THE_32
		and int(gap_result.get("source_id", 0)) == PRIMARY_SOURCE_ID
		and int(gap_result.get("last_sequence", -1)) == TWO_TO_THE_32,
		"accepted-shot records keep source and full-width sequence separate from receipt identity"
	)

	# Receipt identity must remain own-to-target only.
	var wrong_a := target_b.commit_deferred_damage_presentation(receipt4)
	var wrong_b := target_a.commit_deferred_damage_presentation(receipt5)
	var commit_a := target_a.commit_deferred_damage_presentation(receipt1)
	var commit_b := target_b.commit_deferred_damage_presentation(receipt2)
	var commit_c := target_c.commit_deferred_damage_presentation(receipt3)
	var commit_a2 := target_a.commit_deferred_damage_presentation(receipt4)
	var commit_b2 := target_b.commit_deferred_damage_presentation(receipt5)
	var commit_b3 := target_b.commit_deferred_damage_presentation(gap_receipt)
	_check(wrong_a == false and wrong_b == false, "wrong target cannot commit another source's receipt")
	_check(
		commit_a == true and commit_a2 == true and commit_b == true and commit_b2 == true and commit_b3 == true and commit_c == true,
		"each target commit call consumes only its own deferred hit receipt once"
	)
	_check(
		target_a.get_pending_receipt_count() == 0 and target_b.get_pending_receipt_count() == 0 and target_c.get_pending_receipt_count() == 0,
		"all pending receipts are consumed once per target"
	)

	# A deliberate source reset may restart its request sequence, but receipt
	# identity belongs to the authority session and must never restart with it.
	authority.forget_source(source, PRIMARY_SOURCE_ID)
	var reset_registered := authority.register_source(
		source,
		PRIMARY_SOURCE_ID,
		&"test_force",
		TEST_WEAPON_PROFILES
	)
	var post_reset_shot := _shoot(authority, source, target_a)
	var post_reset_request := post_reset_shot.get("request") as ShotRequestType
	var post_reset_receipt := int(post_reset_shot.get("receipt_id", -1))
	_check(
		reset_registered
		and post_reset_request != null
		and post_reset_request.sequence == 0
		and post_reset_receipt > gap_receipt,
		"source reset restarts its sequence without resetting or reusing the session receipt"
	)
	_check(
		target_a.commit_deferred_damage_presentation(post_reset_receipt)
		and not target_a.commit_deferred_damage_presentation(post_reset_receipt),
		"post-reset receipt commits its exact target once"
	)

	# Detach/re-add the same authority instance; receipt IDs keep monotonic state
	# across Main-like tree streaming boundaries.
	_check(authority_holder != null, "authority instance is attached to a shared holder")
	authority_holder.remove_child(authority)
	await process_frame
	var detached_shot := _shoot(authority, source, target_b)
	_check(
		not bool(detached_shot.get("result", {}).get("accepted", false)),
		"authority detached from tree does not issue accepted deferred-receipt shots during reentry cycle"
	)
	authority_holder.add_child(authority)
	await process_frame
	await process_frame
	var post_reentry_shot: Dictionary = _shoot(authority, source, target_b)
	_check(
		int(post_reentry_shot.get("receipt_id", -1)) > post_reset_receipt,
		"presentation receipt sequence remains monotonic after authority detachment/re-entry"
	)

	# Fail-closed behavior at the 64-bit signed upper bound stays bounded.
	authority.set("_next_presentation_receipt_id", INT64_MAX - 2)
	var pre_saturation: int = int(authority.get("_next_presentation_receipt_id"))
	var saturation_1: Dictionary = _shoot(authority, source, target_a)
	var saturation_2: Dictionary = _shoot(authority, source, target_b)
	var saturation_3: Dictionary = _shoot(authority, source, target_c)
	var saturation_1_receipt := int(saturation_1.get("receipt_id", -1))
	var saturation_2_receipt := int(saturation_2.get("receipt_id", -1))
	_check(
		bool(saturation_1.get("result", {}).get("accepted", false)) and saturation_1_receipt == pre_saturation,
		"allocator grants the last in-range receipt"
	)
	_check(
		bool(saturation_2.get("result", {}).get("accepted", false)) and saturation_2_receipt == pre_saturation + 1,
		"allocator grants exactly one terminal in-range receipt before closure"
	)
	_check(
		(not bool(saturation_3.get("result", {}).get("accepted", false)))
		and int(saturation_3.get("receipt_id", -1)) == -1,
		"allocator fail-closes at and beyond the signed 64-bit max"
	)
	_check(
		authority.get("_next_presentation_receipt_id") == -1,
		"allocator cursor marks exhaustion after saturation"
	)

	authority.forget_source(source, PRIMARY_SOURCE_ID)
	authority.forget_source(high_source_a, HIGH_SOURCE_ID_A)
	authority.forget_source(high_source_b, HIGH_SOURCE_ID_B)
	authority.queue_free()
	if authority_holder != null:
		authority_holder.queue_free()
	source.queue_free()
	high_source_a.queue_free()
	high_source_b.queue_free()
	target_a.queue_free()
	target_b.queue_free()
	target_c.queue_free()
	await process_frame
	await process_frame
	_check(
		root.get_child_count() == original_root_child_count,
		"receipt identity fixture returns to a clean scene"
	)
	_finish()


func _build_authority_fixture() -> CombatAuthority:
	var authority := CombatAuthority.new() as CombatAuthority
	authority.name = "LiveCombatAuthority"
	var authority_holder := Node3D.new()
	authority_holder.name = "ReceiptAuthorityFixture"
	authority_holder.add_child(authority)
	authority.authoritative_shot_submitted.connect(_on_shot_submitted)
	root.add_child(authority_holder)
	return authority


func _make_node(node_name: StringName, position: Vector3) -> Node3D:
	var source := Node3D.new()
	source.name = node_name
	source.position = position
	var shape_root := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	shape_root.shape = shape
	source.add_child(shape_root)
	root.add_child(source)
	return source


func _make_target(node_name: StringName, position: Vector3) -> ReceiptTarget:
	var target := ReceiptTarget.new() as ReceiptTarget
	target.name = node_name
	target.position = position
	target.collision_layer = 1 << 2
	target.collision_mask = 1 << 2
	target.damageable.maximum_health = 999.0
	target.damageable.name = "Damageable"
	root.add_child(target)
	return target


func _shoot(
	authority: CombatAuthority,
	source: Node3D,
	target: ReceiptTarget
) -> Dictionary:
	var index := _captured_requests.size()
	var result := authority.submit_hitscan_with_deferred_presentation(
		source,
		WEAPON_ID,
		source.global_position,
		(target.global_position - source.global_position).normalized(),
	)
	var request: ShotRequestType = null
	if index < _captured_requests.size():
		request = _captured_requests[index]
	return {
		"result": result,
		"request": request,
		"receipt_id": int(request.presentation_receipt_id) if request != null else -1,
	}


func _on_shot_submitted(request: ShotRequestType, result: Dictionary) -> void:
	_captured_requests.append(request)
	_captured_results.append(result.duplicate(true))


func _legacy_bitpacked_receipt(source_id: int, sequence: int) -> int:
	return (source_id << 32) | (sequence & 0xffffffff)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("COMBAT_RECEIPT_IDENTITY_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("COMBAT_RECEIPT_IDENTITY_TEST_FAILED: " + "; ".join(_failures))
		quit(1)
