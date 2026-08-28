class_name PlanetaryReturnBerthAdapter
extends RefCounted

## Caller-routed Mudds return berth handoff. ShipBerth remains the lease and
## occupancy authority; this adapter only validates the receipt and delegates.

const DESTINATION_ID: StringName = &"mudds_shipyards"
var _state: StringName = &"ready"
var _berth: ShipBerth
var _ship: Node
var _definition: ShipDefinition
var _token: StringName = &""
var _actor_instance_id := 0
var _craft_instance_id := 0
var _session_generation := 0
var _attachment_generation := 0
var _occupied_receipt: Dictionary = {}
var _contract_completed := false
var _lease_owned := false

## The physical-arrival path adopts the lease already acquired by GameFlow and
## the landing assist.  These snapshots are evidence only: this adapter never
## reserves, occupies, releases, moves, or reparents anything on that path.
var _physical_shell_receipt: Dictionary = {}
var _physical_shell_generation := 0
var _physical_frame_generation := 0
var _physical_hero_attachment_generation := 0
var _physical_berth_instance_id := 0
var _physical_berth_parent_instance_id := 0
var _physical_berth_transform := Transform3D.IDENTITY
var _physical_landing_half_extents := Vector3.ZERO
var _physical_arrival_completed := false

func request(
		arrival_receipt: Variant,
		berth: ShipBerth,
		ship: Node,
		definition: ShipDefinition,
		actor_instance_id: int,
		craft_instance_id: int,
		session_generation: int,
		attachment_generation: int = 1
	) -> Dictionary:
	if _state != &"ready" or not arrival_receipt is Dictionary \
			or berth == null or ship == null or definition == null \
			or actor_instance_id < 1 or craft_instance_id < 1 \
			or session_generation < 1 or attachment_generation < 1:
		return _reject(&"invalid_return_berth_request")
	var receipt := arrival_receipt as Dictionary
	if not bool(receipt.get("accepted", false)) \
			or StringName(receipt.get("return_target_id", &"")) != DESTINATION_ID:
		return _reject(&"return_arrival_receipt_invalid")
	if not berth.is_inside_tree() or not ship.is_inside_tree() \
			or not berth.can_accept(definition, ship):
		return _reject(&"return_berth_unavailable")
	var token := berth.try_reserve(ship, definition)
	if token.is_empty():
		return _reject(&"return_berth_reservation_rejected")
	_berth = berth
	_ship = ship
	_definition = definition
	_token = token
	_actor_instance_id = actor_instance_id
	_craft_instance_id = craft_instance_id
	_session_generation = session_generation
	_attachment_generation = attachment_generation
	_lease_owned = true
	_state = &"reserved"
	return {"accepted": true, "reason": &"return_berth_reserved", "berth_id": berth.get_berth_id(), "token": token, "actor_instance_id": actor_instance_id, "craft_instance_id": craft_instance_id, "session_generation": session_generation}.duplicate(true)


## Adopts the exact home-berth token already owned by the ordinary station
## landing lifecycle.  The caller invokes this only after HeroShip accepted its
## real landing assist, so `landing_started` is the pre-completion generation
## fence and no second movement or lease authority is created here.
func adopt_physical_arrival(
		shell_handoff: Variant,
		current_shell_generation: int,
		current_coordinate_frame_generation: int,
		current_session_generation: int,
		current_attachment_generation: int,
		berth: ShipBerth,
		ship: Node,
		definition: ShipDefinition,
		existing_token: StringName,
		actor_instance_id: int,
		craft_instance_id: int
	) -> Dictionary:
	if _state != &"ready" or not shell_handoff is Dictionary \
			or current_shell_generation < 1 \
			or current_coordinate_frame_generation < 1 \
			or current_session_generation < 1 \
			or current_attachment_generation < 1 \
			or berth == null or ship == null or definition == null \
			or existing_token.is_empty() or actor_instance_id < 1 \
			or craft_instance_id < 1:
		return _reject(&"invalid_physical_arrival_adoption")
	if not is_instance_valid(berth) or not is_instance_valid(ship) \
			or not berth.is_inside_tree() or not ship.is_inside_tree() \
			or craft_instance_id != ship.get_instance_id() \
			or not definition.is_definition_valid():
		return _reject(&"physical_arrival_actor_unavailable")
	var shell := shell_handoff as Dictionary
	var shell_rejection := _physical_shell_rejection(
		shell, ship, current_shell_generation,
		current_coordinate_frame_generation
	)
	if not shell_rejection.is_empty():
		return _reject(shell_rejection)
	if not ship.has_method(&"get_home_berth_id") \
			or StringName(ship.call(&"get_home_berth_id")) != berth.get_berth_id():
		return _reject(&"physical_arrival_wrong_home_berth")
	if ship.has_method(&"get_ship_id") \
			and StringName(ship.call(&"get_ship_id")) != definition.ship_id:
		return _reject(&"physical_arrival_ship_definition_mismatch")
	if berth.get_reservation_owner() != ship \
			or berth.get_reservation_token(ship) != existing_token \
			or not berth.has_valid_lease(ship, existing_token, definition.ship_id):
		return _reject(&"physical_arrival_existing_lease_invalid")
	var hero_report := _hero_attachment_report(ship)
	if hero_report.is_empty() \
			or int(hero_report.get("ship_instance_id", 0)) != craft_instance_id \
			or int(hero_report.get("ship_attachment_generation", 0)) < 1 \
			or int(hero_report.get("controller_instance_id", -1)) != 0 \
			or bool(hero_report.get("attached", true)) \
			or not bool(hero_report.get("landing_active", false)) \
			or bool(hero_report.get("destroyed", true)) \
			or StringName(hero_report.get("reason", &"")) != &"landing_started":
		return _reject(&"physical_arrival_landing_not_current")
	_berth = berth
	_ship = ship
	_definition = definition
	_token = existing_token
	_actor_instance_id = actor_instance_id
	_craft_instance_id = craft_instance_id
	_session_generation = current_session_generation
	_attachment_generation = current_attachment_generation
	_lease_owned = false
	_physical_shell_receipt = shell.duplicate(true)
	_physical_shell_generation = current_shell_generation
	_physical_frame_generation = current_coordinate_frame_generation
	_physical_hero_attachment_generation = int(
		hero_report.get("ship_attachment_generation", 0)
	)
	_physical_berth_instance_id = berth.get_instance_id()
	var berth_parent := berth.get_parent()
	_physical_berth_parent_instance_id = (
		berth_parent.get_instance_id() if is_instance_valid(berth_parent) else 0
	)
	_physical_berth_transform = berth.get_dock_transform()
	_physical_landing_half_extents = berth.get_landing_half_extents()
	_state = &"physical_arrival_adopted"
	return {
		"accepted": true,
		"reason": &"physical_arrival_adopted",
		"berth_id": berth.get_berth_id(),
		"token": existing_token,
		"actor_instance_id": actor_instance_id,
		"craft_instance_id": craft_instance_id,
		"session_generation": current_session_generation,
		"attachment_generation": current_attachment_generation,
		"coordinate_frame_generation": current_coordinate_frame_generation,
		"hero_attachment_generation": _physical_hero_attachment_generation,
	}.duplicate(true)

func confirm_occupied(landing_evidence: Variant) -> Dictionary:
	if _state != &"reserved" or _berth == null or _ship == null:
		return _reject(&"return_berth_reservation_required")
	if not landing_evidence is Dictionary:
		return _reject(&"landing_evidence_required")
	var evidence := landing_evidence as Dictionary
	if not bool(evidence.get("accepted", false)) or not bool(evidence.get("strict_dock_acceptance", false)):
		return _reject(&"landing_evidence_rejected")
	if not _berth.has_valid_lease(_ship, _token, _definition.ship_id):
		return _reject(&"return_berth_lease_lost")
	if not _berth.occupy(_ship, _token):
		return _reject(&"return_berth_occupancy_rejected")
	_state = &"occupied"
	_occupied_receipt = {"accepted": true, "reason": &"return_berth_occupied", "berth_id": _berth.get_berth_id(), "token": _token, "actor_instance_id": _actor_instance_id, "craft_instance_id": _craft_instance_id, "session_generation": _session_generation, "attachment_generation": _attachment_generation}.duplicate(true)
	return _occupied_receipt.duplicate(true)


## Confirms only the already-committed HeroShip landing.  Every mutable identity
## is re-read before a detached occupied receipt is emitted; no occupancy call is
## made here.
func confirm_physical_arrival(
		landing_evidence: Variant,
		current_shell_generation: int,
		current_coordinate_frame_generation: int,
		current_session_generation: int,
		current_attachment_generation: int
	) -> Dictionary:
	if _state != &"physical_arrival_adopted" \
			or _berth == null or _ship == null or _definition == null:
		return _reject(&"physical_arrival_adoption_required")
	if not landing_evidence is Dictionary:
		return _reject(&"landing_evidence_required")
	var identity_rejection := _physical_identity_rejection(
		current_shell_generation, current_coordinate_frame_generation,
		current_session_generation, current_attachment_generation
	)
	if not identity_rejection.is_empty():
		return _reject(identity_rejection)
	var evidence := landing_evidence as Dictionary
	var dock_transform_snapshot: Variant = evidence.get(
		"dock_transform_snapshot", null
	)
	var landing_half_extents_snapshot: Variant = evidence.get(
		"landing_half_extents_snapshot", null
	)
	if bool(evidence.get("active", true)) \
			or StringName(evidence.get("phase", &"")) != &"docked" \
			or not bool(evidence.get("contract_accepted", false)) \
			or not bool(evidence.get("strict_dock_acceptance", false)) \
			or not bool(evidence.get("reservation_token_bound", false)) \
			or StringName(evidence.get("berth_id", &"")) != _berth.get_berth_id() \
			or int(evidence.get("berth_instance_id", 0)) != _physical_berth_instance_id \
			or int(evidence.get("berth_parent_instance_id", 0)) \
				!= _physical_berth_parent_instance_id \
			or StringName(evidence.get("reserved_ship_id", &"")) \
				!= _definition.ship_id \
			or not dock_transform_snapshot is Transform3D \
			or not landing_half_extents_snapshot is Vector3 \
			or not (dock_transform_snapshot as Transform3D).is_equal_approx(
				_physical_berth_transform
			) \
			or not (landing_half_extents_snapshot as Vector3).is_equal_approx(
				_physical_landing_half_extents
			):
		return _reject(&"physical_arrival_landing_evidence_rejected")
	var hero_report := _hero_attachment_report(_ship)
	if hero_report.is_empty() \
			or int(hero_report.get("ship_attachment_generation", 0)) \
				!= _physical_hero_attachment_generation + 1 \
			or int(hero_report.get("controller_instance_id", -1)) != 0 \
			or bool(hero_report.get("attached", true)) \
			or bool(hero_report.get("landing_active", true)) \
			or bool(hero_report.get("destroyed", true)) \
			or StringName(hero_report.get("reason", &"")) != &"landing_completed":
		return _reject(&"physical_arrival_hero_generation_mismatch")
	var live_rejection := _physical_live_berth_rejection(true)
	if not live_rejection.is_empty():
		return _reject(live_rejection)
	_state = &"physical_arrival_occupied"
	_occupied_receipt = {
		"accepted": true,
		"reason": &"return_berth_occupied",
		"berth_id": _berth.get_berth_id(),
		"token": _token,
		"actor_instance_id": _actor_instance_id,
		"craft_instance_id": _craft_instance_id,
		"session_generation": _session_generation,
		"attachment_generation": _attachment_generation,
		"coordinate_frame_generation": _physical_frame_generation,
		"shell_generation": _physical_shell_generation,
		"hero_attachment_generation": int(
			hero_report.get("ship_attachment_generation", 0)
		),
	}.duplicate(true)
	return _occupied_receipt.duplicate(true)

func complete_return_contract(
		occupied_receipt: Variant, landing_return_contract: Object,
		observation: Dictionary
	) -> Dictionary:
	if _state != &"occupied" or _contract_completed:
		return _reject(&"return_contract_completion_unavailable")
	if not occupied_receipt is Dictionary or landing_return_contract == null \
			or not landing_return_contract.has_method(&"confirm_orbit_return"):
		return _reject(&"invalid_return_contract_completion")
	var receipt := occupied_receipt as Dictionary
	if not bool(receipt.get("accepted", false)) \
			or StringName(receipt.get("berth_id", &"")) != _berth.get_berth_id() \
			or StringName(receipt.get("token", &"")) != _token \
			or int(receipt.get("actor_instance_id", 0)) != _actor_instance_id \
			or int(receipt.get("craft_instance_id", 0)) != _craft_instance_id \
			or int(receipt.get("session_generation", 0)) != _session_generation \
			or int(receipt.get("attachment_generation", 0)) != _attachment_generation:
		return _reject(&"foreign_or_stale_berth_receipt")
	var result: Dictionary = landing_return_contract.call(
		&"confirm_orbit_return", true, DESTINATION_ID, observation,
		_session_generation, _attachment_generation
	)
	if not bool(result.get("accepted", false)):
		return result
	_contract_completed = true
	return {"accepted": true, "reason": &"returned_to_station", "berth_receipt": _occupied_receipt.duplicate(true), "contract_receipt": result.duplicate(true)}


## Emits the terminal station receipt from the exact occupied evidence above.
## It is an evidence handoff only and is deliberately separate from the older
## PlanetaryLandingReturnContract completion API.
func complete_physical_arrival(
		occupied_receipt: Variant,
		current_shell_generation: int,
		current_coordinate_frame_generation: int,
		current_session_generation: int,
		current_attachment_generation: int
	) -> Dictionary:
	if _state != &"physical_arrival_occupied" or _physical_arrival_completed:
		return _reject(&"physical_arrival_completion_unavailable")
	if not occupied_receipt is Dictionary \
			or not _physical_occupied_receipt_matches(occupied_receipt as Dictionary):
		return _reject(&"foreign_or_stale_berth_receipt")
	var identity_rejection := _physical_identity_rejection(
		current_shell_generation, current_coordinate_frame_generation,
		current_session_generation, current_attachment_generation
	)
	if not identity_rejection.is_empty():
		return _reject(identity_rejection)
	var live_rejection := _physical_live_berth_rejection(true)
	if not live_rejection.is_empty():
		return _reject(live_rejection)
	var hero_report := _hero_attachment_report(_ship)
	if hero_report.is_empty() \
			or int(hero_report.get("ship_attachment_generation", 0)) \
			!= int(_occupied_receipt.get("hero_attachment_generation", -1)) \
			or int(hero_report.get("controller_instance_id", -1)) != 0 \
			or bool(hero_report.get("attached", true)) \
			or bool(hero_report.get("landing_active", true)) \
			or StringName(hero_report.get("reason", &"")) != &"landing_completed" \
			or bool(hero_report.get("destroyed", true)):
		return _reject(&"physical_arrival_hero_generation_mismatch")
	_physical_arrival_completed = true
	_contract_completed = true
	return {
		"accepted": true,
		"reason": &"returned_to_station",
		"berth_receipt": _occupied_receipt.duplicate(true),
		"contract_receipt": {
			"accepted": true,
			"reason": &"physical_station_arrival_completed",
			"return_target_id": DESTINATION_ID,
			"shell_generation": _physical_shell_generation,
			"target_generation": int(
				_physical_shell_receipt.get("target_generation", 0)
			),
			"coordinate_frame_generation": _physical_frame_generation,
			"session_generation": _session_generation,
			"attachment_generation": _attachment_generation,
			"hero_attachment_generation": int(
				_occupied_receipt.get("hero_attachment_generation", 0)
			),
			"actor_instance_id": _actor_instance_id,
			"craft_instance_id": _craft_instance_id,
			"authority": {
				"movement": false,
				"teleport": false,
				"reparent": false,
				"berth": false,
				"reservation": false,
				"occupancy": false,
				"release": false,
				"reward": false,
				"game_flow": false,
			},
		}.duplicate(true),
	}.duplicate(true)


## Clears one incomplete physical attempt after the real landing owner aborts.
## The shared token is intentionally untouched so GameFlow remains the only
## release authority and can choose whether to retry or release it.
func abort_physical_arrival(reason: StringName) -> Dictionary:
	if _state not in [&"physical_arrival_adopted", &"physical_arrival_occupied"]:
		return _reject(&"physical_arrival_abort_unavailable")
	if reason.is_empty() or _physical_arrival_completed:
		return _reject(&"physical_arrival_abort_invalid")
	_clear_physical_state()
	_state = &"ready"
	return {"accepted": true, "reason": reason, "lease_mutated": false}

func reset() -> Dictionary:
	var physical_path := _state in [
		&"physical_arrival_adopted", &"physical_arrival_occupied",
	]
	if _lease_owned and _berth != null and _ship != null and not _token.is_empty():
		_berth.release(_ship, _token)
	if physical_path:
		_clear_all_state()
	else:
		# Preserve the legacy adapter's retained identity/generation snapshot.
		# Existing callers rely on `retire()` advancing from that attachment even
		# after a reset; only its owned token and terminal evidence are cleared.
		_state = &"ready"
		_token = &""
		_occupied_receipt.clear()
		_contract_completed = false
		_lease_owned = false
	return {"accepted": true, "reason": &"return_berth_reset"}

func retire(next_session_generation: int) -> Dictionary:
	if next_session_generation <= _session_generation:
		return _reject(&"stale_return_retire_generation")
	var next_attachment_generation := _attachment_generation + 1
	var released := reset()
	if not bool(released.get("accepted", false)):
		return released
	_session_generation = next_session_generation
	_attachment_generation = next_attachment_generation
	return {"accepted": true, "reason": &"return_berth_retired", "session_generation": _session_generation, "attachment_generation": _attachment_generation}

func get_snapshot() -> Dictionary:
	return {"state": _state, "berth_id": _berth.get_berth_id() if _berth != null else &"", "token": _token, "actor_instance_id": _actor_instance_id, "craft_instance_id": _craft_instance_id, "session_generation": _session_generation, "attachment_generation": _attachment_generation, "contract_completed": _contract_completed, "physical_arrival_completed": _physical_arrival_completed, "physical_shell_generation": _physical_shell_generation, "physical_frame_generation": _physical_frame_generation, "physical_hero_attachment_generation": _physical_hero_attachment_generation, "lease_owned": _lease_owned, "authority": {"movement": false, "teleport": false, "reparent": false, "berth": false, "reservation": false, "occupancy": false, "release": false, "game_flow": false, "reward": false}}.duplicate(true)


func _physical_shell_rejection(
		receipt: Dictionary,
		ship: Node,
		current_shell_generation: int,
		current_coordinate_frame_generation: int
	) -> StringName:
	if not bool(receipt.get("accepted", false)) \
			or StringName(receipt.get("reason", &"")) \
				!= &"return_approach_handoff_ready" \
			or StringName(receipt.get("home_target_id", &"")) != DESTINATION_ID \
			or int(receipt.get("generation", 0)) != current_shell_generation \
			or int(receipt.get("target_generation", 0)) < 1 \
			or int(receipt.get("coordinate_frame_generation", 0)) \
				!= current_coordinate_frame_generation \
			or int(receipt.get("ship_instance_id", 0)) != ship.get_instance_id():
		return &"physical_arrival_shell_stale"
	var release := receipt.get("controller_release", {}) as Dictionary
	var completion := receipt.get("controller_completion", {}) as Dictionary
	var target := completion.get("target", {}) as Dictionary
	var measurement := completion.get("measurement", {}) as Dictionary
	if int(receipt.get("released_ship_attachment_generation", 0)) < 1 \
			or not bool(release.get("accepted", false)) \
			or StringName(completion.get("reason", &"")) \
				!= &"return_approach_completed" \
			or int(completion.get("target_generation", 0)) \
				!= int(receipt.get("target_generation", -1)) \
			or int(completion.get("coordinate_frame_generation", 0)) \
				!= current_coordinate_frame_generation \
			or int(completion.get("ship_instance_id", 0)) != ship.get_instance_id() \
			or StringName(target.get("home_target_id", &"")) != DESTINATION_ID \
			or not bool(measurement.get("accepted", false)) \
			or not bool(measurement.get("inside_brake_complete_shell", false)) \
			or not bool(measurement.get(
				"full_flyable_fleet_corridor_proven", false
			)):
		return &"physical_arrival_shell_invalid"
	return &""


func _physical_identity_rejection(
		current_shell_generation: int,
		current_coordinate_frame_generation: int,
		current_session_generation: int,
		current_attachment_generation: int
	) -> StringName:
	if current_shell_generation != _physical_shell_generation:
		return &"physical_arrival_shell_stale"
	if current_coordinate_frame_generation != _physical_frame_generation:
		return &"physical_arrival_frame_stale"
	if current_session_generation != _session_generation:
		return &"physical_arrival_session_stale"
	if current_attachment_generation != _attachment_generation:
		return &"physical_arrival_attachment_stale"
	return &""


func _physical_live_berth_rejection(require_occupant: bool) -> StringName:
	if _berth == null or _ship == null or _definition == null \
			or not is_instance_valid(_berth) or not is_instance_valid(_ship) \
			or not _berth.is_inside_tree() or not _ship.is_inside_tree() \
			or _berth.get_instance_id() != _physical_berth_instance_id \
			or _berth.get_berth_id() \
				!= StringName(_ship.call(&"get_home_berth_id")):
		return &"physical_arrival_berth_identity_changed"
	var berth_parent := _berth.get_parent()
	var parent_instance_id := (
		berth_parent.get_instance_id() if is_instance_valid(berth_parent) else 0
	)
	if parent_instance_id != _physical_berth_parent_instance_id \
			or not _berth.get_dock_transform().is_equal_approx(
				_physical_berth_transform
			) \
			or not _berth.get_landing_half_extents().is_equal_approx(
				_physical_landing_half_extents
			):
		return &"physical_arrival_berth_changed"
	if _berth.get_reservation_owner() != _ship \
			or _berth.get_reservation_token(_ship) != _token \
			or not _berth.has_valid_lease(_ship, _token, _definition.ship_id):
		return &"physical_arrival_lease_changed"
	if require_occupant and _berth.get_occupant() != _ship:
		return &"physical_arrival_occupant_mismatch"
	return &""


func _physical_occupied_receipt_matches(receipt: Dictionary) -> bool:
	return receipt == _occupied_receipt \
		and bool(receipt.get("accepted", false)) \
		and StringName(receipt.get("reason", &"")) == &"return_berth_occupied"


func _hero_attachment_report(ship: Node) -> Dictionary:
	if ship == null or not ship.has_method(&"get_planetary_cruise_attachment_report"):
		return {}
	var report: Variant = ship.call(&"get_planetary_cruise_attachment_report")
	return (report as Dictionary).duplicate(true) if report is Dictionary else {}


func _clear_physical_state() -> void:
	_berth = null
	_ship = null
	_definition = null
	_token = &""
	_actor_instance_id = 0
	_craft_instance_id = 0
	_session_generation = 0
	_attachment_generation = 0
	_occupied_receipt.clear()
	_contract_completed = false
	_lease_owned = false
	_physical_shell_receipt.clear()
	_physical_shell_generation = 0
	_physical_frame_generation = 0
	_physical_hero_attachment_generation = 0
	_physical_berth_instance_id = 0
	_physical_berth_parent_instance_id = 0
	_physical_berth_transform = Transform3D.IDENTITY
	_physical_landing_half_extents = Vector3.ZERO
	_physical_arrival_completed = false


func _clear_all_state() -> void:
	_clear_physical_state()
	_state = &"ready"

func _reject(reason: StringName) -> Dictionary:
	return {"accepted": false, "reason": reason}
