extends SceneTree

## Focused regression for the Phase 6 repair-authority seam. It exercises only
## actor/seat/range/resource/cooldown/generation validation and one commit into
## ComponentDamageModel; no scene, physics, renderer, or full matrix is used.

const Authority := preload("res://scripts/combat/repair_authority.gd")
const Model := preload("res://scripts/combat/component_damage_model.gd")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var authority = Authority.new(
		&"pilot_one", &"torrent_hull", &"repair_kit", 4.0, 1.0, 20.0, 1
		)
	_check(authority.is_configuration_valid(), "the authored repair envelope validates")
	_check(bool(authority.begin_generation(1).accepted), "one live lifecycle generation starts")
	_check(
		not bool(authority.begin_generation(1).accepted)
			and authority.begin_generation(1).reason == &"stale_generation",
		"a duplicate generation cannot refill or restart the repair authority"
	)

	var model := _make_model()
	var damage := model.apply_component_damage({
		"component_id": &"hull",
		"damage": 40.0,
		"generation": 1,
		"sequence": 0,
	})
	_check(bool(damage.accepted), "the fixture has one authoritative damaged component")

	var base := _request()
	var invalid := base.duplicate()
	invalid.actor_id = &"other_actor"
	_check(
		not bool(authority.request_repair(invalid).accepted)
			and authority.request_repair(invalid).reason == &"actor_mismatch",
		"a non-owner actor cannot reserve a repair token"
	)
	invalid = base.duplicate()
	invalid.target_id = &"other_hull"
	_check(authority.request_repair(invalid).reason == &"target_mismatch", "a different target is rejected")
	invalid = base.duplicate()
	invalid.distance_meters = 4.01
	_check(authority.request_repair(invalid).reason == &"out_of_range", "a tool outside range is rejected")
	invalid = base.duplicate()
	invalid.seated = false
	_check(authority.request_repair(invalid).reason == &"seat_required", "repair requires the authorized seat")
	invalid = base.duplicate()
	invalid.resource_id = &"wrong_kit"
	_check(authority.request_repair(invalid).reason == &"resource_mismatch", "a different resource cannot repair")
	invalid = base.duplicate()
	invalid.interrupted = true
	_check(authority.request_repair(invalid).reason == &"interrupted", "an interrupted action never reserves a token")

	var requested := authority.request_repair(base)
	var token := int(requested.get("token", -1))
	_check(
		bool(requested.accepted) and token > 0 and authority.has_active_repair(),
		"a valid seated request reserves exactly one repair token"
	)
	_check(
		authority.request_repair(base).reason == &"already_repairing",
		"a second request cannot overlap the active repair"
	)
	var committed := authority.commit_repair(model, token)
	_check(
		bool(committed.accepted)
			and committed.reason == &"committed"
			and is_equal_approx(float(model.get_component_state(&"hull").current_health), 80.0)
			and authority.get_resource_units() == 0
			and is_equal_approx(authority.get_cooldown_remaining(), 1.0),
		"one commit repairs the authoritative component once and spends one resource"
	)
	_check(
		not bool(authority.commit_repair(model, token).accepted)
			and authority.commit_repair(model, token).reason == &"no_active_repair",
		"the committed token cannot be replayed"
	)
	_check(
		authority.request_repair(base).reason == &"cooldown",
		"a committed repair enforces its bounded cooldown"
	)
	_check(bool(authority.advance(1.0).accepted), "the owner can advance cooldown with a physics delta")
	_check(
		authority.request_repair(base).reason == &"resource_exhausted",
		"a depleted repair resource fails closed after cooldown"
	)

	# A pending token is discarded by interruption without charging the resource.
	var stocked = Authority.new(&"pilot_one", &"torrent_hull", &"repair_kit", 4.0, 1.0, 20.0, 1)
	stocked.begin_generation(1)
	var pending := stocked.request_repair(base)
	_check(bool(stocked.interrupt(&"seat_lost").accepted), "seat loss interrupts a pending repair")
	_check(
		not stocked.has_active_repair()
			and stocked.get_resource_units() == 1
			and stocked.interrupt(&"again").reason == &"no_active_repair",
		"interruption clears the token without consuming resource or allowing replay"
	)

	# A crew handoff changes only the actor fence. The same ship-generation stock
	# and cooldown stay authoritative, so releasing/reclaiming a seat cannot refill
	# finite repair kits.
	var handoff_authority = Authority.new(
		&"pilot_one", &"torrent_hull", &"repair_kit", 4.0, 1.0, 5.0, 2
	)
	handoff_authority.begin_generation(1)
	var handoff_commit := handoff_authority.commit_repair(
		model,
		int(handoff_authority.request_repair(base).get("token", -1))
	)
	_check(
		bool(handoff_commit.get("accepted", false))
			and handoff_authority.get_resource_units() == 1
			and handoff_authority.get_resource_capacity() == 2,
		"the fixture spends one unit from a finite two-kit ship inventory"
	)
	var rebound := handoff_authority.rebind_actor(&"pilot_two", 1)
	_check(
		bool(rebound.get("accepted", false))
			and rebound.get("reason", &"") == &"actor_rebound"
			and int(rebound.get("resource_units", -1)) == 1
			and int(rebound.get("resource_capacity", -1)) == 2
			and is_equal_approx(float(rebound.get("cooldown_remaining", 0.0)), 1.0),
		"same-generation actor handoff preserves spent stock and active cooldown"
	)
	_check(
		handoff_authority.rebind_actor(&"pilot_three", 2).get("reason", &"") == &"stale_generation",
		"an actor handoff cannot cross the repair lifecycle generation"
	)
	handoff_authority.advance(1.0)
	var rebound_request := base.duplicate(true)
	rebound_request["actor_id"] = &"pilot_two"
	_check(
		bool(handoff_authority.request_repair(rebound_request).get("accepted", false))
			and handoff_authority.rebind_actor(&"pilot_three", 1).get("reason", &"") == &"repair_active",
		"the rebound actor can use the remaining kit while an active token blocks another handoff"
	)
	handoff_authority.interrupt(&"test_complete")
	_check(
		bool(handoff_authority.begin_generation(2).get("accepted", false))
			and handoff_authority.get_resource_units() == 2,
		"only a newer ship lifecycle restores the authored repair-kit capacity"
	)

	# Only a new accepted component receipt for this authority's exact craft and
	# generation may interrupt. Rejected, unrelated, and replayed observations
	# leave the pending token available, and interruption charges no resource.
	var damage_authority = Authority.new(
		&"pilot_one", &"torrent_hull", &"repair_kit", 4.0, 0.0, 20.0, 2
	)
	damage_authority.begin_generation(1)
	var damage_request := damage_authority.request_repair(base)
	_check(
		bool(damage_request.accepted)
			and bool(damage_authority.observe_component_damage_revision({
				"target_id": &"torrent_hull", "generation": 1, "revision": 5,
			}).accepted),
		"an active engineer repair observes its owning component revision without gaining damage authority"
	)
	var unrelated := _damage_interruption_context(5, 6, true)
	unrelated.target_id = &"other_hull"
	_check(
		damage_authority.interrupt_for_authoritative_component_damage(unrelated).reason == &"target_mismatch"
			and damage_authority.has_active_repair(),
		"accepted damage for another craft cannot interrupt this repair"
	)
	var rejected := _damage_interruption_context(5, 5, false)
	_check(
		damage_authority.interrupt_for_authoritative_component_damage(rejected).reason == &"damage_rejected"
			and damage_authority.has_active_repair(),
		"rejected component damage leaves the repair token active"
	)
	var stale := _damage_interruption_context(4, 5, true)
	_check(
		damage_authority.interrupt_for_authoritative_component_damage(stale).reason == &"stale_damage_revision"
			and damage_authority.has_active_repair(),
		"a stale accepted receipt cannot interrupt the repair"
	)
	var interrupted := damage_authority.interrupt_for_authoritative_component_damage(
		_damage_interruption_context(5, 6, true)
	)
	_check(
		bool(interrupted.accepted)
			and interrupted.reason == &"authoritative_component_damage"
			and interrupted.damage_kind == &"combat"
			and interrupted.component_ids == [&"hull"]
			and not damage_authority.has_active_repair()
			and damage_authority.get_resource_units() == 2,
		"new authoritative combat component damage interrupts with detached semantic evidence and no repair charge"
	)
	var restarted := damage_authority.request_repair(base)
	_check(
		bool(restarted.accepted) and int(restarted.token) > int(damage_request.token),
		"the interrupted authority accepts a fresh repair token immediately afterward"
	)
	damage_authority.observe_component_damage_revision({
		"target_id": &"torrent_hull", "generation": 1, "revision": 6,
	})
	var collision_context := _damage_interruption_context(6, 7, true)
	collision_context.damage_kind = Authority.DAMAGE_KIND_COLLISION
	_check(
		bool(damage_authority.interrupt_for_authoritative_component_damage(collision_context).accepted),
		"the same generation fence accepts authoritative collision component damage"
	)

	# Model generation changes invalidate a reserved action before commit.
	var stale_authority = Authority.new(&"pilot_one", &"torrent_hull", &"repair_kit", 4.0, 1.0, 20.0, 1)
	stale_authority.begin_generation(1)
	var stale_request := stale_authority.request_repair(base)
	model.reset_for_reuse(1)
	_check(
		stale_authority.commit_repair(model, int(stale_request.get("token", -1))).reason == &"stale_generation"
			and stale_authority.get_resource_units() == 1,
		"a model generation change invalidates the token without spending repair resource"
	)

	var fresh = Authority.new(&"pilot_one", &"torrent_hull", &"repair_kit", 4.0, 0.0, 20.0, 1)
	fresh.begin_generation(2)
	_check(
		fresh.get_resource_units() == 1
			and fresh.get_snapshot().authority.damage == false
			and fresh.get_snapshot().authority.presentation == false,
		"a new generation restores its authored resource budget and owns no damage or presentation authority"
	)
	_finish()


func _make_model() -> ComponentDamageModel:
	var model := Model.new([{
		"component_id": &"hull",
		"maximum_health": 100.0,
		"damage_stages": [
			{"stage_id": &"nominal", "health_ratio_at_or_below": 1.0, "disabled": false, "performance_multiplier": 1.0},
			{"stage_id": &"damaged", "health_ratio_at_or_below": 0.5, "disabled": false, "performance_multiplier": 1.0},
			{"stage_id": &"destroyed", "health_ratio_at_or_below": 0.0, "disabled": true, "performance_multiplier": 0.0},
		],
	}]) as ComponentDamageModel
	model.reset_for_reuse(0)
	return model


func _request() -> Dictionary:
	return {
		"actor_id": &"pilot_one",
		"target_id": &"torrent_hull",
		"component_id": &"hull",
		"generation": 1,
		"distance_meters": 2.0,
		"seated": true,
		"resource_id": &"repair_kit",
		"interrupted": false,
	}


func _damage_interruption_context(
	previous_revision: int,
	revision: int,
	accepted: bool
) -> Dictionary:
	return {
		"target_id": &"torrent_hull",
		"generation": 1,
		"previous_revision": previous_revision,
		"revision": revision,
		"accepted": accepted,
		"damage_kind": Authority.DAMAGE_KIND_COMBAT,
		"component_ids": [&"hull"] if accepted else [],
	}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: repair authority (", _assertions, " assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)
