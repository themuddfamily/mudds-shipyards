extends SceneTree
## test-matrix-timeout-seconds: 300
## The Aurora coastal survey and Rime ice-core survey against a real composed
## `Main`: their GameFlow, ActivityDirector, player, HUD and reward authority.
##
## Each survey is attached to a small stand-in surface (a floor, a rotated and
## offset `LandingRegion` and the three named anchors), driven through its own
## `interact()` by an on-foot player, and checked for:
## - a rejected reward store keeps the completed readings and the second E at
##   the final anchor records the reward exactly once;
## - an abandoned survey's objective no longer claims its lost progress;
## - a survey left running when a visit ends does not resume on the next
##   visit's arrival. The expedition keeps one survey for the whole session and
##   attaches it afresh to each visit's surface.

const MAIN := preload("res://scenes/main.tscn")
const MemoryStoreFixture := preload("res://tests/ember_transit_movement_soak.gd")
const AURORA_SURVEY := preload("res://scripts/activities/aurora_coastal_survey.gd")
const RIME_SURVEY := preload("res://scripts/activities/rime_ice_core_survey.gd")
const SUCCESS_MARKER := "PLANETARY_SURVEY_LIFECYCLE_TEST_OK"
const FAILURE_MARKER := "PLANETARY_SURVEY_LIFECYCLE_TEST_FAILED"
const ANCHOR_POINTS := [Vector3(0, 0, 0), Vector3(12, 0, 0), Vector3(24, 0, 0)]

var _failures: Array[String] = []
var _assertions := 0


class StubVisit:
	extends RefCounted
	var state: StringName = &"surface"

	func get_craft() -> HeroShip:
		return null


## Forwards to the real reward store and refuses commits while `reject` is set.
class RejectingStore:
	extends RefCounted
	var inner: RefCounted
	var reject := false
	var rejected := 0

	func get_snapshot() -> Variant:
		return inner.call(&"get_snapshot")

	func get_generation() -> int:
		return int(inner.call(&"get_generation"))

	func commit(payload: Dictionary, generation: int, transaction_id: String) -> Dictionary:
		if reject:
			rejected += 1
			return {"accepted": false, "reason": &"injected_write_failure"}
		return inner.call(&"commit", payload, generation, transaction_id) as Dictionary


class RejectWritesFilesystem extends UserDataFilesystem:
	var attempts := 0

	func write_bytes_and_flush(_path: String, _bytes: PackedByteArray) -> Error:
		attempts += 1
		return ERR_CANT_CREATE


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN.instantiate() as GameFlow
	# Exercise real reward commits without inheriting paid surveys from another
	# test or the player's profile, and without writing these rewards to disk.
	var isolated := game.configure_runtime_settings_persistence(MemoryStoreFixture.Store.new(
		"memory://planetary-survey-lifecycle.json", MemoryStoreFixture.MemoryFilesystem.new()),
		"memory://planetary-survey-lifecycle.cfg")
	_check(isolated, "survey lifecycle uses an isolated production persistence store")
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	for _i in 4:
		await process_frame
		await physics_frame
	var authority: RefCounted = game.get("_game_flow_reward_authority")
	_check(authority != null, "production Main composes the reward authority")
	if authority == null:
		await _finish(game)
		return
	var store := RejectingStore.new()
	store.inner = authority.get("_store")
	authority.set("_store", store)
	await _survey_case(game, store, AURORA_SURVEY, "Aurora", Vector3(4000, 600, 4000))
	await _survey_case(game, store, RIME_SURVEY, "Rime", Vector3(-4000, 600, 4000))
	game.queue_free()
	await process_frame
	await process_frame
	await _unpaid_visit_retirement_case("Aurora", &"_aurora_expedition")
	await _unpaid_visit_retirement_case("Rime", &"_rime_expedition")
	await _finish(null)


## A private real-file profile, fresh Main/store objects and production end-visit
## retirement. Observations use this file's disclosed stand-in surface and
## direct interact calls; the next arrival uses production staged recovery.
## This does not qualify physical outbound/return or an OS-process restart.
func _unpaid_visit_retirement_case(label: String, owner_property: StringName) -> void:
	var path := "user://survey-retirement-%s-%d.json" % [label.to_lower(), Time.get_ticks_usec()]
	var game := await _boot_retirement_profile(path)
	var owner: RefCounted = game.get(owner_property)
	var survey: RefCounted = owner.get("survey")
	var profile: RefCounted = owner.get("profile")
	var binding: RefCounted = game.get(profile.persistence_binding_property)
	var disk := game.get("_runtime_settings_user_data_store") as UserDataStore
	var craft := game.get_node("HalyardCrewTransport") as HeroShip
	var slot := String((binding.call(&"get_snapshot") as Dictionary).slot_id)
	var archive_slot := String(binding.call(&"get_declined_slot_id"))
	var unrelated := {"note": "retain actual unrelated payload", "world": label}
	var initial := disk.get_snapshot()
	initial["survey_retirement_unrelated"] = unrelated
	_check(bool(disk.commit(initial, disk.get_generation(), "survey-retirement-initialize").get("accepted", false)),
		"%s: retirement fixture creates its private real-file primary" % label)
	# The owner/craft association is staged; all observations below are earned
	# through the existing survey interaction on supported stand-in collision.
	game.active_ship = craft
	owner.set("_ship", craft)
	owner.set("state", &"surface")
	var surface := _make_surface(Vector3(4000, 600, 4000))
	survey.call(&"attach", surface)
	var authority: RefCounted = game.get("_game_flow_reward_authority")
	var rejecting_reward := RejectingStore.new()
	rejecting_reward.inner = authority.get("_store")
	authority.set("_store", rejecting_reward)
	await _stand_at(game, surface, 0)
	var started: bool = survey.call(&"interact")
	await _stand_at(game, surface, 1)
	var observed: bool = survey.call(&"interact")
	var incomplete := disk.get_snapshot().get(slot, {}) as Dictionary
	var incomplete_ready := started and observed and not incomplete.is_empty() \
		and int(incomplete.visit.survey.state) == CheckpointRouteActivity.State.ACTIVE \
		and int(incomplete.visit.survey.next_checkpoint_index) == 1
	_check(incomplete_ready, "%s: actual first observation saves an incomplete visit before retirement" % label)
	if not incomplete_ready:
		await _close_retirement_profile(game, owner, surface)
		return
	owner.call(&"_retire_saved_visit")
	_check(not disk.get_snapshot().has(slot) and not disk.get_snapshot().has(archive_slot)
		and disk.get_snapshot().get("survey_retirement_unrelated") == unrelated,
		"%s: incomplete visit retirement clears location without creating earned debt" % label)
	await _stand_at(game, surface, 2)
	rejecting_reward.reject = true
	var completed: bool = survey.call(&"interact")
	rejecting_reward.reject = false
	var earned := (disk.get_snapshot().get(slot, {}) as Dictionary).duplicate(true)
	var earned_ready := completed and rejecting_reward.rejected > 0 and not earned.is_empty() \
		and int(earned.visit.survey.state) == CheckpointRouteActivity.State.COMPLETED \
		and int(earned.visit.survey.next_checkpoint_index) == 2 \
		and not bool(survey.call(&"reward_recorded")) and _reward_count(game, survey) == 0
	_check(earned_ready, "%s: genuine final observation refuses reward publication but saves exact unpaid completion" % label)
	if not earned_ready:
		await _close_retirement_profile(game, owner, surface)
		return
	var reward_before := (authority.call(&"get_snapshot").get("record", {}) as Dictionary).duplicate(true)
	var before_refusal := disk.get_snapshot()
	var generation_before := disk.get_generation()
	var bytes_before := FileAccess.get_file_as_bytes(path)
	var filesystem: RefCounted = disk.get("_filesystem")
	var rejecting_disk := RejectWritesFilesystem.new()
	disk.set("_filesystem", rejecting_disk)
	owner.call(&"_retire_saved_visit")
	disk.set("_filesystem", filesystem)
	_check(rejecting_disk.attempts == 1 and disk.get_snapshot() == before_refusal
		and disk.get_generation() == generation_before and FileAccess.get_file_as_bytes(path) == bytes_before,
		"%s: refused end-visit retirement preserves actual bytes, generation and unpaid completion" % label)
	var invalid_paid := disk.get_snapshot()
	invalid_paid[String(GameFlowRewardAuthority.SLOT_ID)] = {"corrupt": true}
	_check(bool(disk.commit(invalid_paid, disk.get_generation(), "survey-retirement-invalid-paid").get("accepted", false)),
		"%s: private fixture stages an invalid paid authority without changing earned observations" % label)
	var invalid_before := disk.get_snapshot()
	var invalid_bytes := FileAccess.get_file_as_bytes(path)
	var invalid_generation := disk.get_generation()
	owner.call(&"_retire_saved_visit")
	_check(disk.get_snapshot() == invalid_before and disk.get_generation() == invalid_generation
		and FileAccess.get_file_as_bytes(path) == invalid_bytes,
		"%s: invalid paid authority cannot retire the only saved unpaid completion" % label)
	_check(bool(disk.commit(before_refusal, disk.get_generation(), "survey-retirement-restore-authority").get("accepted", false)),
		"%s: private fixture restores its exact earned payload after invalid-authority refusal" % label)
	# An earlier passive descriptor for these genuinely earned observations may
	# differ in saved location metadata. It must not be silently overwritten.
	var conflict := earned.duplicate(true)
	conflict.visit.on_foot = not bool(conflict.visit.on_foot)
	conflict.receipt_sha256 = binding.call(&"digest_visit", conflict.visit)
	var conflicting_payload := disk.get_snapshot()
	conflicting_payload[archive_slot] = conflict
	var conflict_saved := disk.commit(conflicting_payload, disk.get_generation(), "survey-retirement-conflict")
	_check(bool(conflict_saved.get("accepted", false)), "%s: conflicting passive descriptor is durably staged from genuine observations" % label)
	var before_conflict := disk.get_snapshot()
	var conflict_generation := disk.get_generation()
	var conflict_bytes := FileAccess.get_file_as_bytes(path)
	owner.call(&"_retire_saved_visit")
	_check(disk.get_snapshot() == before_conflict and disk.get_generation() == conflict_generation
		and FileAccess.get_file_as_bytes(path) == conflict_bytes,
		"%s: end-visit retirement refuses conflicting unpaid archive without losing either saved record" % label)
	# Restore only this private fixture to the exact earned pre-retirement cut.
	var restored_fixture := disk.get_snapshot()
	restored_fixture.erase(archive_slot)
	restored_fixture[slot] = earned.duplicate(true)
	_check(bool(disk.commit(restored_fixture, disk.get_generation(), "survey-retirement-remove-conflict").get("accepted", false)),
		"%s: private fixture returns to its original genuine unpaid boundary" % label)
	owner.call(&"_retire_saved_visit")
	var retired := disk.get_snapshot()
	var preserved: bool = not retired.has(slot) and retired.get(archive_slot) == earned
	_check(preserved and retired.get("survey_retirement_unrelated") == unrelated
		and (authority.call(&"get_snapshot").get("record", {}) as Dictionary) == reward_before,
		"%s: accepted end-visit retirement preserves exact unpaid observations passively without payment" % label)
	await _close_retirement_profile(game, owner, surface)
	var fresh := await _boot_retirement_profile(path)
	var fresh_owner: RefCounted = fresh.get(owner_property)
	var fresh_survey: RefCounted = fresh_owner.get("survey")
	var fresh_disk := fresh.get("_runtime_settings_user_data_store") as UserDataStore
	var cold_preserved: bool = fresh_disk.get_snapshot().get(archive_slot) == earned
	_check(cold_preserved and not fresh_disk.get_snapshot().has(slot)
		and fresh_owner.get("state") == &"idle" and _reward_count(fresh, fresh_survey) == 0
		and fresh_disk.get_snapshot().get("survey_retirement_unrelated") == unrelated,
		"%s: fresh Main and real-file store retain retired unpaid debt at Mudds without world resume or payment" % label)
	if not preserved or not cold_preserved:
		# The old runtime reaches these loss assertions. Missing debt is the
		# regression, so do not report downstream admission/retry setup failures.
		await _close_retirement_profile(fresh, fresh_owner)
		return
	var fresh_craft := fresh.get_node("HalyardCrewTransport") as HeroShip
	var admission: Dictionary = fresh_owner.call(&"restore_interrupted_visit", {
		"visit_state": "surface", "craft_home_berth_id": String(fresh_craft.get_home_berth_id()),
		"on_foot": true, "survey": {},
	})
	_check(bool(admission.get("accepted", false)), "%s: disclosed staged next admission uses production craft and streaming owner" % label)
	var deadline := Time.get_ticks_msec() + 30_000
	while bool(admission.get("accepted", false)) and Time.get_ticks_msec() < deadline:
		await process_frame
		await physics_frame
		if bool(fresh_owner.call(&"settled_surface_is_current")) and fresh.player.is_on_floor() \
				and _state(fresh_survey) == CheckpointRouteActivity.State.COMPLETED:
			break
	var current := bool(fresh_owner.call(&"settled_surface_is_current")) and fresh.player.is_on_floor()
	_check(current and _state(fresh_survey) == CheckpointRouteActivity.State.COMPLETED
		and int((fresh_survey.call(&"snapshot") as Dictionary).get("generation", -1)) == int(earned.visit.survey.generation)
		and _reward_count(fresh, fresh_survey) == 0,
		"%s: current next surface adopts exact earned generation without automatic payment" % label)
	if not current or _state(fresh_survey) != CheckpointRouteActivity.State.COMPLETED:
		await _close_retirement_profile(fresh, fresh_owner)
		return
	var anchors: Array = fresh_survey.get("_anchors")
	var anchor := anchors[2] as Node3D
	fresh.player.teleport_to(Transform3D(Basis.IDENTITY, anchor.global_position + Vector3(0.6, 0.1, 0)))
	for _frame in 90:
		await physics_frame
		await process_frame
		if _frame >= 6 and fresh.player.is_on_floor():
			break
	var legitimate_retry: bool = fresh_survey.call(&"interact")
	_check(legitimate_retry and bool(fresh_survey.call(&"reward_recorded")) and _reward_count(fresh, fresh_survey) == 1,
		"%s: legitimate final-anchor interaction pays the preserved original completion once" % label)
	var paid: Dictionary = fresh.get_activity_reward_report().get("authority", {}).get("record", {}).duplicate(true)
	fresh_survey.call(&"interact")
	_check(fresh.get_activity_reward_report().get("authority", {}).get("record", {}) == paid
		and _reward_count(fresh, fresh_survey) == 1,
		"%s: repeated interaction cannot pay the retired completion twice" % label)
	# Save the paid current visit, then finish it through the same owner. Paid
	# progress must not replace the already retained passive descriptor.
	var paid_saved: Dictionary = fresh.call(&"save_interrupted_aurora_visit" if label == "Aurora" else &"save_interrupted_rime_visit")
	_check(bool(paid_saved.get("accepted", false)) and fresh_disk.get_snapshot().has(slot),
		"%s: paid current visit is saved before normal retirement" % label)
	fresh_owner.call(&"_retire_saved_visit")
	_check(not fresh_disk.get_snapshot().has(slot) and fresh_disk.get_snapshot().get(archive_slot) == earned
		and _reward_count(fresh, fresh_survey) == 1,
		"%s: paid visit retires normally without replacing old passive observations or paying again" % label)
	await _close_retirement_profile(fresh, fresh_owner)


func _boot_retirement_profile(path: String) -> GameFlow:
	var game := MAIN.instantiate() as GameFlow
	_check(game.configure_runtime_settings_persistence(UserDataStore.new(path), path + ".cfg"),
		"retirement Main binds its isolated real-file store before startup")
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	for _frame in 4:
		await process_frame
		await physics_frame
	return game


func _close_retirement_profile(game: GameFlow, owner: RefCounted, surface: Node3D = null) -> void:
	# This fixture calls the end-visit seam directly. Avoid a tree-detach save
	# reintroducing the intentionally retired active location on teardown.
	owner.set("state", &"idle")
	owner.set("_ship", null)
	if is_instance_valid(surface):
		if (owner.get("survey") as RefCounted).has_method(&"detach"):
			(owner.get("survey") as RefCounted).call(&"detach")
		surface.queue_free()
	game.mark_orderly_shutdown()
	game.queue_free()
	for _frame in 6:
		await process_frame
		await physics_frame


func _survey_case(game: GameFlow, store: RejectingStore, script: GDScript, label: String,
		origin: Vector3) -> void:
	var visit := StubVisit.new()
	var survey: RefCounted = script.new(game, visit)
	var surface := _make_surface(origin)
	survey.attach(surface)

	# Abandoning after one reading loses that reading.
	await _stand_at(game, surface, 0)
	_check(survey.interact() and _state(survey) == CheckpointRouteActivity.State.ACTIVE,
		"%s: E at the start anchor starts the survey" % label)
	if script == RIME_SURVEY:
		survey.physics_tick(15.0)
		_check(is_equal_approx(float(survey.get_heat_snapshot().heat_s), RIME_SURVEY.HEAT_CAPACITY_S - 15.0),
			"Rime: the active on-foot survey spends heat")
		_heat_progress_case(survey)
	await _stand_at(game, surface, 1)
	_check(survey.interact() and int(survey.snapshot().next_checkpoint_index) == 1,
		"%s: E at the first anchor records reading 1/2" % label)
	await _stand_at(game, surface, 0)
	_check(survey.interact() and _state(survey) == CheckpointRouteActivity.State.FAILED,
		"%s: E at the start anchor abandons the running survey" % label)
	if script == RIME_SURVEY:
		_check(is_equal_approx(float(survey.get_heat_snapshot().heat_s), RIME_SURVEY.HEAT_CAPACITY_S),
			"Rime: abandoning resets the heater for a fresh survey")
	var abandoned_objective := String(survey.objective())
	_check(not abandoned_objective.contains("1/2"),
		"%s: an abandoned survey's objective does not claim lost progress (%s)" % [label, abandoned_objective])

	# A survey left running when the visit ends.
	_check(survey.interact() and _state(survey) == CheckpointRouteActivity.State.ACTIVE,
		"%s: the start anchor starts a fresh survey" % label)
	await _stand_at(game, surface, 1)
	_check(survey.interact() and int(survey.snapshot().next_checkpoint_index) == 1,
		"%s: the fresh survey records reading 1/2 before the visit ends" % label)
	if script == RIME_SURVEY:
		survey.physics_tick(25.0)
	visit.state = &"boarding"
	if survey.has_method(&"detach"):
		survey.call(&"detach")
	surface.queue_free()
	await process_frame
	await physics_frame
	var next_surface := _make_surface(origin + Vector3(37, -3, -52))
	visit.state = &"surface"
	survey.attach(next_surface)
	if script == RIME_SURVEY:
		_check(is_equal_approx(float(survey.get_heat_snapshot().heat_s), RIME_SURVEY.HEAT_CAPACITY_S),
			"Rime: a fresh visit resets heat instead of carrying the previous visit's expenditure")
	var carried := String(survey.objective())
	_check(_state(survey) != CheckpointRouteActivity.State.ACTIVE and not carried.contains("1/2"),
		"%s: a survey left running on the previous visit does not resume on arrival (%s)" % [label, carried])

	# Complete with a rejecting store, then retry.
	await _stand_at(game, next_surface, 0)
	if _state(survey) == CheckpointRouteActivity.State.ACTIVE:
		survey.interact()
	_check(survey.interact() and _state(survey) == CheckpointRouteActivity.State.ACTIVE,
		"%s: the next visit starts its own survey" % label)
	await _stand_at(game, next_surface, 1)
	survey.interact()
	await _stand_at(game, next_surface, 2)
	store.reject = true
	var rejected_before := store.rejected
	_check(survey.interact() and _state(survey) == CheckpointRouteActivity.State.COMPLETED
			and not survey.reward_recorded() and store.rejected > rejected_before,
		"%s: a rejected reward write keeps the completed readings unrecorded" % label)
	_check(String(survey.prompt()).begins_with("[ E ]"),
		"%s: the final anchor still offers E to retry the reward" % label)
	if script == RIME_SURVEY:
		_check(String(survey.prompt()) == "[ E ]  RETRY SAVING RECORD"
				and String(survey.objective()).contains("retry saving"),
			"Rime: completed unpaid readings label the next interaction as save retry, not another strain reading")
	store.reject = false
	_check(survey.interact() and survey.reward_recorded() and _reward_count(game, survey) == 1,
		"%s: the retry records the reward once" % label)
	_check(not survey.interact() and _reward_count(game, survey) == 1,
		"%s: another E cannot record the reward twice" % label)
	next_surface.queue_free()
	await process_frame


func _heat_progress_case(survey: RefCounted) -> void:
	var progress := survey.capture() as Dictionary
	_check(RIME_SURVEY.valid_progress(progress)
			and is_equal_approx(float(progress.get("heat_s", -1.0)), float(survey.get_heat_snapshot().heat_s)),
		"Rime: captured progress includes the spent heater")
	var legacy := progress.duplicate(true)
	legacy.erase("heat_s")
	_check(RIME_SURVEY.valid_progress(legacy), "Rime: earlier saves without heat remain loadable")
	for invalid_heat: Variant in [-1.0, RIME_SURVEY.HEAT_CAPACITY_S + 1.0, INF, NAN, "50", true]:
		var malformed := progress.duplicate(true)
		malformed["heat_s"] = invalid_heat
		_check(not RIME_SURVEY.valid_progress(malformed),
			"Rime: invalid saved heat is rejected (%s)" % str(invalid_heat))
	for saved_heat: Variant in [50, 46.5500000000002, 50.0 / 3.0]:
		var heat_progress := progress.duplicate(true)
		heat_progress["heat_s"] = saved_heat
		var binding := RimeExpeditionPersistenceBinding.new()
		var normalized := binding.normalize_visit({
			"visit_state": "surface", "craft_home_berth_id": "test_berth",
			"on_foot": true, "survey": heat_progress,
		})
		var visit := normalized.get("visit", {}) as Dictionary
		# Match UserDataStore's default precision, rather than the receipt's.
		var round_trip := JSON.parse_string(JSON.stringify(visit)) as Dictionary
		_check(bool(normalized.get("accepted", false))
				and (visit.get("survey", {}) as Dictionary).get("heat_s") is float
				and RimeExpeditionPersistenceBinding._digest(visit) == RimeExpeditionPersistenceBinding._digest(round_trip),
			"Rime: saved heat keeps a stable store-precision JSON receipt (%s)" % saved_heat)



func _make_surface(origin: Vector3) -> Node3D:
	var surface := Node3D.new()
	surface.name = "StandInSurface"
	root.add_child(surface)
	surface.global_position = origin
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	surface.add_child(floor_body)
	floor_body.position = Vector3(0, -0.5, 0)
	var region := Node3D.new()
	region.name = "LandingRegion"
	surface.add_child(region)
	region.position = Vector3(-6, 0, 5)
	region.rotation.y = 0.7
	var names: Array = AURORA_SURVEY.ANCHORS + RIME_SURVEY.ANCHORS
	for index in names.size():
		var anchor := Marker3D.new()
		anchor.name = names[index]
		region.add_child(anchor)
		anchor.position = ANCHOR_POINTS[index % 3]
	return surface


func _stand_at(game: GameFlow, surface: Node3D, index: int) -> void:
	var region := surface.get_node("LandingRegion") as Node3D
	var target := region.to_global(ANCHOR_POINTS[index]) + Vector3(0.6, 0.1, 0)
	game.player.teleport_to(Transform3D(Basis.IDENTITY, target))
	for _i in 90:
		await physics_frame
		await process_frame
		if _i >= 6 and game.player.is_on_floor():
			break


func _state(survey: RefCounted) -> int:
	return int(survey.snapshot().get("state", -1))


func _reward_count(game: GameFlow, survey: RefCounted) -> int:
	var authority: RefCounted = game.get("_game_flow_reward_authority")
	var record := authority.call(&"get_snapshot").get("record", {}) as Dictionary
	return int((record.get("reward_counts", {}) as Dictionary).get(String(survey.REWARD_ID), 0))


func _check(ok: bool, message: String) -> void:
	_assertions += 1
	if not ok:
		_failures.append(message)
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)


func _finish(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame
	print("%s: %d assertions" % [
		SUCCESS_MARKER if _failures.is_empty() else FAILURE_MARKER, _assertions,
	])
	quit(0 if _failures.is_empty() else 1)
