class_name WingCoordinator
extends Node

## Role assignment for a coordinated opponent wing.
##
## This node owns exactly one thing: which enlisted member is the **anchor**
## (the craft that deliberately holds the player's forward arc and trades shots
## head-on) and which are **flankers** (craft that refuse the frontal fight,
## swing for the player's rear hemisphere, and only arm their guns once they
## are actually behind him). It owns no health, no damage, no combat
## registration, no movement and no phase. Members read their assigned role and
## decide their own motion and firing; nothing here can apply damage.
##
## Why a separate node rather than peer-to-peer chatter between two craft: the
## assignment has to be a single decision made once per physics step from one
## consistent snapshot. Two craft each deciding "am I the anchor?" from their
## own `_physics_process` can both answer yes on the same frame — which is
## exactly the bug that makes a "coordinated pair" read as two identical craft
## flying at you. One owner, one decision, deterministic order.
##
## Determinism. There is no randomness here. Ties break on the member's stable
## `wing_priority` (its combat source identity), so the same positions always
## produce the same assignment, and a headless suite sees what the renderer saw.
##
## Evidence status: modern_interpretation. No original Keth Shipyards formation,
## tactic, doctrine, or unit name is authenticated or claimed by this component.

signal role_changed(member: Node3D, role: StringName)
signal roles_assigned(assignments: Dictionary)

const SCHEMA_VERSION := 1
const COMPONENT_ID: StringName = &"wing-coordinator"
const EVIDENCE_STATUS: StringName = &"modern_interpretation"

const ROLE_UNASSIGNED: StringName = &"unassigned"
const ROLE_ANCHOR: StringName = &"anchor"
const ROLE_FLANKER: StringName = &"flanker"
const ROLES: Array[StringName] = [ROLE_UNASSIGNED, ROLE_ANCHOR, ROLE_FLANKER]

## Hard bound on enlistment. A wing is a pair in production; the bound exists so
## a mis-wired scene fails an audit instead of growing an unbounded roster.
const MAX_MEMBERS := 4

const CONTENT_NOTE := (
	"The anchor/flanker split, the swap margin, the swap hold, and the "
	+ "hurt-anchor relief rule are an original modern interpretation. They do "
	+ "not reproduce or claim any authenticated historical Keth Shipyards "
	+ "formation, doctrine, tactic, or unit name."
)

@export_category("Coordination")
@export var enabled := true
## How much better a challenger's claim on the frontal arc must be before it can
## take the anchor role. Without a margin the pair oscillates every frame the
## player's nose crosses the midpoint between them.
@export_range(0.0, 1.0, 0.01) var role_swap_margin := 0.25
## How long that advantage must be held, in accumulated physics seconds, before
## the swap commits. This is the window in which the player's turn has actually
## bought him something: neither craft has a good firing solution while the wing
## re-forms.
@export_range(0.0, 5.0, 0.05) var role_swap_hold := 0.9
## A hurt anchor rotates out. Below this hull ratio the healthier peer takes the
## frontal job even though the geometry still favours the incumbent, so focusing
## one craft down while ignoring the other does not work.
@export_range(0.0, 1.0, 0.01) var anchor_relief_ratio := 0.4

var _members: Array[Node3D] = []
var _roles: Dictionary = {}
var _target: Node3D
var _pending_challenger: Node3D
var _pending_hold := 0.0
var _swap_count := 0
var _assignment_count := 0


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	update_assignments(delta)


# -------------------------------------------------------------- roster ----

## Adds a member to the wing. Idempotent; returns false when the member is
## invalid or the fixed roster bound is already met.
func enlist(member: Node3D) -> bool:
	if not is_instance_valid(member):
		return false
	if _members.has(member):
		return true
	if _members.size() >= MAX_MEMBERS:
		push_warning("WingCoordinator: enlistment refused, roster is at its fixed bound")
		return false
	_members.append(member)
	_roles[member.get_instance_id()] = ROLE_UNASSIGNED
	return true


## Removes a member and clears its role. Safe to call for a member that was
## never enlisted, and safe during that member's own teardown.
func dismiss(member: Node3D) -> void:
	var index := _members.find(member)
	if index >= 0:
		_members.remove_at(index)
	if is_instance_valid(member):
		_roles.erase(member.get_instance_id())
	if _pending_challenger == member:
		_clear_pending_swap()


func dismiss_all() -> void:
	for member in _members.duplicate():
		if is_instance_valid(member):
			_roles.erase(member.get_instance_id())
	_members.clear()
	_roles.clear()
	_clear_pending_swap()


## The craft the wing is co-ordinating against. Roles are geometric with respect
## to this craft's facing, so without one every member is unassigned.
func set_target(target: Node3D) -> void:
	var resolved_target := target if _is_live_target(target) else null
	if _target == resolved_target:
		return
	_target = resolved_target
	_clear_pending_swap()


func get_target() -> Node3D:
	return _target if _has_live_target() else null


func get_member_count() -> int:
	return _members.size()


func get_active_member_count() -> int:
	return _collect_active_members().size()


func get_role(member: Node3D) -> StringName:
	if not is_instance_valid(member):
		return ROLE_UNASSIGNED
	return _roles.get(member.get_instance_id(), ROLE_UNASSIGNED)


func get_anchor() -> Node3D:
	for member in _members:
		if is_instance_valid(member) and get_role(member) == ROLE_ANCHOR:
			return member
	return null


func get_swap_count() -> int:
	return _swap_count


func get_assignment_count() -> int:
	return _assignment_count


# --------------------------------------------------------- assignment ----

## Recomputes the assignment from one consistent snapshot. Public so a suite can
## step it deterministically without waiting on the physics clock.
func update_assignments(delta: float) -> void:
	# Preserve standalone/pre-tree deterministic stepping, but a coordinator
	# retained only until the deferred free drain must not reassign live members.
	if is_queued_for_deletion():
		return
	_prune_invalid_members()
	if _members.is_empty():
		# An empty wing has nothing to decide. Returning here keeps the idle
		# per-frame cost at one array check rather than a full re-assignment
		# sweep, and keeps the assignment counter meaningful as a count of real
		# decisions rather than of frames elapsed.
		_clear_pending_swap()
		return
	var active := _collect_active_members()
	if active.is_empty() or not _has_live_target():
		_target = null
		_clear_pending_swap()
		_assign_all(ROLE_UNASSIGNED)
		return

	# A lone survivor always fights head-on. This is the readable consequence of
	# killing half a wing: the fight stops being a pincer and becomes a duel.
	if active.size() == 1:
		_clear_pending_swap()
		_commit_anchor(active[0])
		return

	var claims := {}
	for member in active:
		claims[member.get_instance_id()] = _frontal_claim(member)

	var incumbent := get_anchor()
	if not is_instance_valid(incumbent) or not active.has(incumbent):
		_clear_pending_swap()
		_commit_anchor(_best_claimant(active, claims))
		return

	var relief := _relief_candidate(incumbent, active)
	if is_instance_valid(relief):
		# A hurt anchor rotates out immediately; there is no geometric hold on a
		# craft that is about to die in the player's gunsight.
		_clear_pending_swap()
		_commit_anchor(relief)
		return

	var challenger := _best_claimant_excluding(active, claims, incumbent)
	var incumbent_claim := float(claims.get(incumbent.get_instance_id(), -1.0))
	var challenger_claim := (
		float(claims.get(challenger.get_instance_id(), -1.0))
		if is_instance_valid(challenger)
		else -1.0
	)
	if not is_instance_valid(challenger) or challenger_claim < incumbent_claim + role_swap_margin:
		_clear_pending_swap()
		_commit_anchor(incumbent)
		return

	if _pending_challenger != challenger:
		_pending_challenger = challenger
		_pending_hold = 0.0
	if is_finite(delta) and delta > 0.0:
		_pending_hold += delta
	if _pending_hold < role_swap_hold:
		# The swap is claimed but not yet paid for. The wing is mid-reform: the
		# incumbent still anchors and the challenger is still a flanker, which is
		# the window a turning player is actually buying.
		_commit_anchor(incumbent)
		return
	_clear_pending_swap()
	_commit_anchor(challenger)


## How strongly a member sits in the target's forward arc. Higher is a stronger
## claim on the anchor role: the craft the player is already looking at is the
## one that should be trading shots with him.
func _frontal_claim(member: Node3D) -> float:
	if not _has_live_target() or not is_instance_valid(member):
		return -1.0
	var offset := member.global_position - _target.global_position
	if offset.length_squared() <= 0.000001:
		return 1.0
	return (-_target.global_basis.z).dot(offset.normalized())


func _relief_candidate(incumbent: Node3D, active: Array[Node3D]) -> Node3D:
	var incumbent_ratio := _health_ratio(incumbent)
	if incumbent_ratio > anchor_relief_ratio:
		return null
	var best: Node3D = null
	var best_ratio := incumbent_ratio
	for member in active:
		if member == incumbent:
			continue
		var ratio := _health_ratio(member)
		if ratio > best_ratio:
			best_ratio = ratio
			best = member
	return best


func _health_ratio(member: Node3D) -> float:
	if not is_instance_valid(member):
		return 0.0
	if not member.has_method(&"get_health"):
		return 1.0
	var maximum := 1.0
	var declared: Variant = member.get(&"maximum_health")
	if declared is float or declared is int:
		maximum = maxf(0.001, float(declared))
	return clampf(float(member.call(&"get_health")) / maximum, 0.0, 1.0)


func _best_claimant(active: Array[Node3D], claims: Dictionary) -> Node3D:
	return _best_claimant_excluding(active, claims, null)


func _best_claimant_excluding(
		active: Array[Node3D],
		claims: Dictionary,
		excluded: Node3D
	) -> Node3D:
	var best: Node3D = null
	var best_claim := -2.0
	for member in active:
		if member == excluded:
			continue
		var claim := float(claims.get(member.get_instance_id(), -1.0))
		if best == null or claim > best_claim + 0.0001:
			best = member
			best_claim = claim
		elif absf(claim - best_claim) <= 0.0001 and _priority(member) < _priority(best):
			# Exact geometric ties break on stable identity, never on roster order.
			best = member
			best_claim = claim
	return best


func _priority(member: Node3D) -> int:
	if not is_instance_valid(member):
		return 1 << 30
	if member.has_method(&"get_wing_priority"):
		return int(member.call(&"get_wing_priority"))
	return int(member.get_instance_id())


func _commit_anchor(anchor: Node3D) -> void:
	var changed := false
	for member in _members:
		if not is_instance_valid(member):
			continue
		var role := ROLE_UNASSIGNED
		if _is_member_active(member):
			role = ROLE_ANCHOR if member == anchor else ROLE_FLANKER
		if _set_role(member, role):
			changed = true
			if role == ROLE_ANCHOR:
				_swap_count += 1
	_assignment_count += 1
	if changed:
		roles_assigned.emit(get_assignments())


func _assign_all(role: StringName) -> void:
	var changed := false
	for member in _members:
		if is_instance_valid(member) and _set_role(member, role):
			changed = true
	_assignment_count += 1
	if changed:
		roles_assigned.emit(get_assignments())


func _set_role(member: Node3D, role: StringName) -> bool:
	var key := member.get_instance_id()
	if _roles.get(key, ROLE_UNASSIGNED) == role:
		return false
	_roles[key] = role
	if member.has_method(&"assign_wing_role"):
		member.call(&"assign_wing_role", role)
	role_changed.emit(member, role)
	return true


func _clear_pending_swap() -> void:
	_pending_challenger = null
	_pending_hold = 0.0


func _prune_invalid_members() -> void:
	var index := _members.size() - 1
	var pruned := false
	while index >= 0:
		if not is_instance_valid(_members[index]):
			_members.remove_at(index)
			pruned = true
		index -= 1
	if pruned:
		# A freed member's instance id can no longer be read back, so the role
		# table is rebuilt from the surviving roster rather than key-erased.
		var surviving := {}
		for member in _members:
			var key := member.get_instance_id()
			surviving[key] = _roles.get(key, ROLE_UNASSIGNED)
		_roles = surviving
	if not is_instance_valid(_pending_challenger):
		_clear_pending_swap()


func _collect_active_members() -> Array[Node3D]:
	var active: Array[Node3D] = []
	for member in _members:
		if _is_member_active(member):
			active.append(member)
	return active


func _is_member_active(member: Node3D) -> bool:
	return (
		is_instance_valid(member)
		and member.is_inside_tree()
		and member.has_method(&"is_active")
		and bool(member.call(&"is_active"))
	)


func _has_live_target() -> bool:
	return _is_live_target(_target)


func _is_live_target(target: Node3D) -> bool:
	return is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion()


# ------------------------------------------------------------- audit ----

## Role by member instance id. A deep copy, so a caller cannot mutate the
## coordinator's assignment by holding the returned dictionary.
func get_assignments() -> Dictionary:
	var assignments := {}
	for member in _members:
		if is_instance_valid(member):
			assignments[member.get_instance_id()] = get_role(member)
	return assignments


func get_evidence_metadata() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"evidence_status": EVIDENCE_STATUS,
		"historically_supported": false,
		"authenticated_original_tactic": false,
		"claims_historical_unit_name": false,
		"modern_interpretations": PackedStringArray([
			"anchor and flanker role split within an opponent wing",
			"frontal-arc claim, swap margin, and swap hold window",
			"hurt-anchor relief rotation",
		]),
		"explicit_unknowns": PackedStringArray([
			"any historical opposing formation, doctrine, tactic, or unit name",
		]),
		"content_note": CONTENT_NOTE,
	}.duplicate(true)


func get_audit_report() -> Dictionary:
	var errors := get_validation_errors()
	var roles := {}
	for member in _members:
		if is_instance_valid(member):
			roles[String(member.name)] = String(get_role(member))
	return {
		"schema_version": SCHEMA_VERSION,
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"evidence": get_evidence_metadata(),
		"enabled": enabled,
		"members": _members.size(),
		"active_members": get_active_member_count(),
		"roles": roles,
		"anchor": String(get_anchor().name) if is_instance_valid(get_anchor()) else "",
		"assignments": _assignment_count,
		"anchor_commits": _swap_count,
		"pending_swap_hold": _pending_hold,
		"target": String(_target.name) if is_instance_valid(_target) else "",
		"tuning": {
			"role_swap_margin": role_swap_margin,
			"role_swap_hold": role_swap_hold,
			"anchor_relief_ratio": anchor_relief_ratio,
		},
	}.duplicate(true)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if _members.size() > MAX_MEMBERS:
		errors.append("wing roster exceeds the fixed bound")
	if _roles.size() > _members.size():
		errors.append("role table retains entries for members that are no longer enlisted")
	var anchors := 0
	for member in _members:
		if is_instance_valid(member) and get_role(member) == ROLE_ANCHOR:
			anchors += 1
	if anchors > 1:
		errors.append("more than one anchor is assigned at the same time")
	if (
		_assignment_count > 0
		and get_active_member_count() > 0
		and is_instance_valid(_target)
		and anchors != 1
	):
		errors.append("an engaged wing must hold exactly one anchor")
	if _assignment_count > 0 and get_active_member_count() == 0 and anchors != 0:
		errors.append("a stood-down wing must hold no anchor")
	if not is_finite(role_swap_hold) or role_swap_hold < 0.0:
		errors.append("role swap hold must be finite and non-negative")
	if not is_finite(_pending_hold) or _pending_hold < 0.0:
		errors.append("pending swap hold must be finite and non-negative")
	return errors
