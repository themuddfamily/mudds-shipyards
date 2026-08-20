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
