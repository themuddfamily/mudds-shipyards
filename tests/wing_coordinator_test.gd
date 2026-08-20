extends SceneTree

## Focused regression for `WingCoordinator`, the single owner of which craft in
## an opponent wing is the anchor.
##
## The component is deliberately exercised against stand-in members rather than
## against `FlankingSkirmisherOpponent`, because the property under test is the
## *decision*, not the craft: exactly one anchor at a time, chosen from one
## consistent snapshot, with a hold window a player can actually feel and a
## relief rule that stops a wing being defeated by focusing one half of it.
## Production integration with the real craft is covered by
## `tests/varied_encounter_integration_test.gd`.
##
## Every assertion below is a value or an invariant, never node existence, and
## the RED section at the end mutates the three rules that carry the behaviour
## and requires each mutation to turn the audit red.

const CoordinatorScript := preload("res://scripts/combat/wing_coordinator.gd")

var _failures: Array[String] = []
var _assertion_count := 0
var _role_events: Array[Dictionary] = []


## Minimal stand-in with exactly the four seams the coordinator reads.
class WingMember:
	extends Node3D

	var active := true
	var health := 100.0
	var maximum_health := 100.0
	var priority := 0
	var assigned_role: StringName = &"unassigned"
	var assignment_count := 0

	func is_active() -> bool:
		return active

	func get_health() -> float:
		return health

	func get_wing_priority() -> int:
		return priority

	func assign_wing_role(role: StringName) -> void:
		assigned_role = role
		assignment_count += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_children := root.get_child_count()
	await _test_single_member_always_anchors()
	await _test_frontal_craft_anchors_and_peer_flanks()
	await _test_swap_requires_margin_and_hold()
	await _test_hurt_anchor_is_relieved_immediately()
	await _test_stand_down_and_roster_lifecycle()
	await _test_queued_target_stands_down_and_live_rebinds()
	await _test_red_mutations()
	_check(
		root.get_child_count() == original_children,
		"every coordinator fixture cleans up without leaving scene nodes"
	)
	_finish()


# ------------------------------------------------------------ behaviour ----

func _test_single_member_always_anchors() -> void:
	var fixture := await _make_fixture(1)
	var coordinator: WingCoordinator = fixture.coordinator
	var lone: WingMember = fixture.members[0]
	_place(lone, Vector3(0.0, 0.0, -140.0))
	coordinator.update_assignments(0.0)
	_check(
		coordinator.get_role(lone) == WingCoordinator.ROLE_ANCHOR,
		"a lone survivor takes the anchor role regardless of geometry"
	)
	# Behind the target, where a flanker would sit: it still anchors, because a
	# single craft with nothing to coordinate with has no flank to hold.
	_place(lone, Vector3(0.0, 0.0, 140.0))
	coordinator.update_assignments(0.5)
	_check(
		coordinator.get_role(lone) == WingCoordinator.ROLE_ANCHOR,
		"a lone survivor still anchors from the target's rear hemisphere"
	)
	_check(
		lone.assigned_role == WingCoordinator.ROLE_ANCHOR and lone.assignment_count == 1,
		"the role is pushed to the member exactly once while it does not change"
	)
	_check(
		coordinator.get_validation_errors().is_empty(),
		"a single-member engaged wing passes its own audit"
	)
	await _free_fixture(fixture)


func _test_frontal_craft_anchors_and_peer_flanks() -> void:
	var fixture := await _make_fixture(2)
	var coordinator: WingCoordinator = fixture.coordinator
	var ahead: WingMember = fixture.members[0]
	var behind: WingMember = fixture.members[1]
	# The fixture target looks down -Z, so -Z is in front of it.
	_place(ahead, Vector3(0.0, 0.0, -120.0))
	_place(behind, Vector3(0.0, 0.0, 120.0))
	coordinator.update_assignments(0.0)
	_check(
		coordinator.get_role(ahead) == WingCoordinator.ROLE_ANCHOR,
		"the craft inside the target's forward arc takes the anchor role"
	)
	_check(
		coordinator.get_role(behind) == WingCoordinator.ROLE_FLANKER,
		"the craft behind the target is assigned the flanking role"
	)
	_check(
		coordinator.get_anchor() == ahead and coordinator.get_active_member_count() == 2,
		"the coordinator reports exactly one anchor across a two-craft wing"
	)
	var assignments := coordinator.get_assignments()
	assignments[ahead.get_instance_id()] = &"tampered"
	_check(
		coordinator.get_role(ahead) == WingCoordinator.ROLE_ANCHOR,
		"the returned assignment table is a copy and cannot mutate the coordinator"
	)
	await _free_fixture(fixture)


func _test_swap_requires_margin_and_hold() -> void:
	var fixture := await _make_fixture(2)
	var coordinator: WingCoordinator = fixture.coordinator
	var target: Node3D = fixture.target
	var first: WingMember = fixture.members[0]
	var second: WingMember = fixture.members[1]
	_place(first, Vector3(0.0, 0.0, -120.0))
	_place(second, Vector3(0.0, 0.0, 120.0))
	coordinator.update_assignments(0.0)
	_check(
		coordinator.get_role(first) == WingCoordinator.ROLE_ANCHOR,
		"the wing forms with the forward craft anchoring"
	)

	# A shallow turn that does not clear the margin must change nothing at all,
	# however long it is held. Facing 60 degrees off gives the rear craft a claim
	# of -0.5 against the forward craft's +0.5: a full point of margin is needed.
	_face(target, Vector3(0.87, 0.0, -0.5))
	for _step in 20:
		coordinator.update_assignments(0.1)
	_check(
		coordinator.get_role(first) == WingCoordinator.ROLE_ANCHOR,
		"a turn that does not clear the swap margin never trades the anchor role"
	)

	# A full reversal does clear it, but only after the hold window is paid.
	_face(target, Vector3(0.0, 0.0, 1.0))
	coordinator.update_assignments(0.1)
	_check(
		coordinator.get_role(first) == WingCoordinator.ROLE_ANCHOR
		and coordinator.get_role(second) == WingCoordinator.ROLE_FLANKER,
		"the anchor role does not change on the frame the player's turn completes"
	)
	var elapsed := 0.1
	while elapsed < coordinator.role_swap_hold - 0.05:
		coordinator.update_assignments(0.1)
		elapsed += 0.1
	_check(
		coordinator.get_role(first) == WingCoordinator.ROLE_ANCHOR,
		"the incumbent holds the anchor role for the whole swap-hold window"
	)
	coordinator.update_assignments(0.2)
	_check(
		coordinator.get_role(second) == WingCoordinator.ROLE_ANCHOR
		and coordinator.get_role(first) == WingCoordinator.ROLE_FLANKER,
		"the wing trades roles once the swap hold has been paid in full"
	)
	_check(
		coordinator.get_validation_errors().is_empty(),
		"a wing that has just traded roles still holds exactly one anchor"
	)
	await _free_fixture(fixture)


func _test_hurt_anchor_is_relieved_immediately() -> void:
	var fixture := await _make_fixture(2)
	var coordinator: WingCoordinator = fixture.coordinator
	var hurt: WingMember = fixture.members[0]
	var fresh: WingMember = fixture.members[1]
	_place(hurt, Vector3(0.0, 0.0, -120.0))
	_place(fresh, Vector3(0.0, 0.0, 120.0))
	coordinator.update_assignments(0.0)
	_check(
		coordinator.get_role(hurt) == WingCoordinator.ROLE_ANCHOR,
		"the wing forms with the forward craft anchoring before it is hurt"
	)
	# Focusing one half of the wing does not remove half the wing's pressure:
	# the healthy peer rotates in on the very next evaluation, with no hold.
	hurt.health = hurt.maximum_health * (coordinator.anchor_relief_ratio - 0.05)
	coordinator.update_assignments(0.0)
	_check(
		coordinator.get_role(fresh) == WingCoordinator.ROLE_ANCHOR
		and coordinator.get_role(hurt) == WingCoordinator.ROLE_FLANKER,
		"a hurt anchor is relieved by its healthier peer without paying the swap hold"
	)
	# Relief is comparative, not absolute: if both are equally hurt there is
	# nobody to rotate to, and the incumbent keeps the job.
	fresh.health = hurt.health
	coordinator.update_assignments(0.0)
	_check(
		coordinator.get_role(fresh) == WingCoordinator.ROLE_ANCHOR,
		"relief does not fire when no peer is in better shape than the incumbent"
	)
	await _free_fixture(fixture)


func _test_stand_down_and_roster_lifecycle() -> void:
	var fixture := await _make_fixture(2)
	var coordinator: WingCoordinator = fixture.coordinator
	var first: WingMember = fixture.members[0]
	var second: WingMember = fixture.members[1]
	_place(first, Vector3(0.0, 0.0, -120.0))
	_place(second, Vector3(0.0, 0.0, 120.0))
	coordinator.update_assignments(0.0)
	_role_events.clear()

	# Destroying the anchor promotes the survivor on the next evaluation, which
	# is the state change a player sees as the fight becoming a duel.
	first.active = false
	coordinator.update_assignments(0.0)
	_check(
		coordinator.get_role(second) == WingCoordinator.ROLE_ANCHOR
		and coordinator.get_role(first) == WingCoordinator.ROLE_UNASSIGNED,
		"losing the anchor promotes the surviving flanker and clears the dead craft's role"
	)
	_check(
		_role_events.size() == 2,
		"exactly one role change is announced per member that actually changed (%d)"
			% _role_events.size()
	)

	# A wing with nothing left flying holds no anchor at all.
	second.active = false
	coordinator.update_assignments(0.0)
	_check(
		coordinator.get_anchor() == null and coordinator.get_active_member_count() == 0,
		"a wing with no active member holds no anchor"
	)
	_check(
		coordinator.get_validation_errors().is_empty(),
		"a stood-down wing passes its own audit"
	)

	# Losing the target clears every role: the roles are defined relative to it.
	first.active = true
	second.active = true
	coordinator.update_assignments(0.0)
	coordinator.set_target(null)
	coordinator.update_assignments(0.0)
	_check(
		coordinator.get_anchor() == null,
		"a wing with no target holds no anchor"
	)

	# Enlistment is idempotent and bounded.
	_check(
		coordinator.enlist(first) and coordinator.get_member_count() == 2,
		"re-enlisting an existing member does not duplicate it"
	)
	_check(
		not coordinator.enlist(null),
		"an invalid member cannot be enlisted"
	)
	coordinator.dismiss(first)
	_check(
		coordinator.get_member_count() == 1 and coordinator.get_role(first) == WingCoordinator.ROLE_UNASSIGNED,
		"a dismissed member leaves the roster and keeps no role"
	)
	coordinator.dismiss_all()
	_check(
		coordinator.get_member_count() == 0 and coordinator.get_audit_report().roles.is_empty(),
		"dismissing the whole wing empties both the roster and the role table"
	)
	await _free_fixture(fixture)


func _test_queued_target_stands_down_and_live_rebinds() -> void:
	var fixture := await _make_fixture(2)
	var coordinator: WingCoordinator = fixture.coordinator
	var target: Node3D = fixture.target
	var first: WingMember = fixture.members[0]
	var second: WingMember = fixture.members[1]
	_place(first, Vector3(0.0, 0.0, -120.0))
	_place(second, Vector3(0.0, 0.0, 120.0))
	coordinator.update_assignments(0.0)
	_role_events.clear()
	var assignments_before := coordinator.get_assignment_count()
	target.queue_free()
	coordinator.update_assignments(0.0)
	_check(
		target.is_queued_for_deletion()
		and coordinator.get_target() == null
		and coordinator.get("_target") == null
		and coordinator.get_role(first) == WingCoordinator.ROLE_UNASSIGNED
		and coordinator.get_role(second) == WingCoordinator.ROLE_UNASSIGNED
		and _role_events.size() == 2
		and coordinator.get_assignment_count() == assignments_before + 1,
		"a queued target synchronously clears the retained binding and stands down every wing role"
	)
	await process_frame
	var rebound_target := Node3D.new()
	rebound_target.name = "ReboundCoordinationTarget"
	var host := fixture.host as Node3D
	host.add_child(rebound_target)
	_face(rebound_target, Vector3(0.0, 0.0, -1.0))
	coordinator.set_target(rebound_target)
	coordinator.update_assignments(0.0)
	_check(
		coordinator.get_target() == rebound_target
		and coordinator.get_role(first) == WingCoordinator.ROLE_ANCHOR
		and coordinator.get_role(second) == WingCoordinator.ROLE_FLANKER,
		"a fresh live target rebinds and restores the ordinary anchor/flanker assignment"
	)
	await _free_fixture(fixture)


# ----------------------------------------------------------------- red ----

func _test_red_mutations() -> void:
	# RED 1: two craft with identical geometry must still yield one anchor. If
	# ties did not break on stable identity this would produce two.
	var fixture := await _make_fixture(2)
	var coordinator: WingCoordinator = fixture.coordinator
	var first: WingMember = fixture.members[0]
	var second: WingMember = fixture.members[1]
	_place(first, Vector3(0.0, 0.0, -120.0))
	_place(second, Vector3(0.0, 0.0, -120.0))
	coordinator.update_assignments(0.0)
	var anchors := 0
	for member in [first, second]:
		if coordinator.get_role(member) == WingCoordinator.ROLE_ANCHOR:
			anchors += 1
	_check(
		anchors == 1 and coordinator.get_anchor() == first,
		"RED 1: an exact geometric tie resolves to one anchor, chosen by stable identity"
	)

	# RED 2: forcing a second anchor into the role table must fail the audit.
	# This is the state the whole component exists to prevent.
	var roles: Dictionary = coordinator.get("_roles")
	roles[second.get_instance_id()] = WingCoordinator.ROLE_ANCHOR
	coordinator.set("_roles", roles)
	var duplicate_errors := coordinator.get_validation_errors()
	_check(
		duplicate_errors.size() > 0
		and _errors_mention(duplicate_errors, "more than one anchor"),
		"RED 2: two simultaneous anchors turn the coordinator audit red"
	)
	coordinator.update_assignments(0.0)
	_check(
		coordinator.get_validation_errors().is_empty(),
		"RED 2: the next evaluation repairs the injected duplicate anchor"
	)

	# RED 3: a negative hold accumulator is an unbounded swap window and must be
	# rejected rather than silently clamped.
	coordinator.set("_pending_hold", -1.0)
	_check(
		_errors_mention(coordinator.get_validation_errors(), "pending swap hold"),
		"RED 3: a negative swap-hold accumulator turns the audit red"
	)
	coordinator.set("_pending_hold", 0.0)

	# RED 4: an engaged wing that has been left with no anchor is red.
	var cleared := {}
	for member in [first, second]:
		cleared[member.get_instance_id()] = WingCoordinator.ROLE_UNASSIGNED
	coordinator.set("_roles", cleared)
	_check(
		_errors_mention(coordinator.get_validation_errors(), "exactly one anchor"),
		"RED 4: an engaged wing with no anchor turns the audit red"
	)
	await _free_fixture(fixture)


func _errors_mention(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if error.contains(fragment):
			return true
	return false


# ------------------------------------------------------------- fixture ----

func _make_fixture(member_count: int) -> Dictionary:
	_role_events.clear()
	var host := Node3D.new()
	host.name = "WingCoordinatorTestWorld"
	root.add_child(host)

	var target := Node3D.new()
	target.name = "CoordinationTarget"
	host.add_child(target)
	target.global_position = Vector3.ZERO
	_face(target, Vector3(0.0, 0.0, -1.0))

	var coordinator := CoordinatorScript.new() as WingCoordinator
	coordinator.name = "WingCoordinator"
	# The suite steps the assignment itself, so the component's own physics pass
	# cannot race the deterministic sequence under test.
	coordinator.enabled = false
	host.add_child(coordinator)
	coordinator.role_changed.connect(_on_role_changed)

	var members: Array[WingMember] = []
	for index in member_count:
		var member := WingMember.new()
		member.name = "WingMember%d" % index
		member.priority = 2100 + index
		host.add_child(member)
		coordinator.enlist(member)
		members.append(member)
	coordinator.set_target(target)

	await process_frame
	await physics_frame
	return {"host": host, "coordinator": coordinator, "target": target, "members": members}


func _free_fixture(fixture: Dictionary) -> void:
	var host := fixture.get("host") as Node3D
	if is_instance_valid(host):
		root.remove_child(host)
		host.queue_free()
	for _index in 4:
		await process_frame


func _place(member: WingMember, position: Vector3) -> void:
	member.global_position = position


func _face(node: Node3D, direction: Vector3) -> void:
	var forward := direction.normalized()
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.965 else Vector3.FORWARD
	node.global_basis = Basis.looking_at(forward, up).orthonormalized()


func _on_role_changed(member: Node3D, role: StringName) -> void:
	_role_events.append({"member": member, "role": role})


# ------------------------------------------------------------- harness ----

func _check(condition: bool, description: String) -> void:
	_assertion_count += 1
	if condition:
		print("PASS: %s" % description)
	else:
		_failures.append(description)
		print("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("WING_COORDINATOR_TEST_OK: %d assertions" % _assertion_count)
		quit(0)
	else:
		print("WING_COORDINATOR_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
