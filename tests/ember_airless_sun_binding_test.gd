extends SceneTree

const BOOTSTRAP_SCENE := preload(
	"res://scenes/world/components/ember_moon_streaming_bootstrap.tscn"
)
const RIG_SCENE := preload(
	"res://scenes/world/components/ember_airless_sun_rig.tscn"
)
const EMBER_WORLD := preload(
	"res://assets/world/planets/ember_moon_world.tres"
)
const EXPECTED_ASSERTIONS := 42

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_authored_standalone_rig()
	await _test_exact_configuration_and_airless_mapping()
	await _test_generation_rebase_and_lifecycle()
	await _test_unload_replacement_and_reports()
	_finish()


func _test_authored_standalone_rig() -> void:
	var host := Node3D.new()
	host.name = "StandaloneHost"
	root.add_child(host)
	var rig := RIG_SCENE.instantiate() as EmberAirlessSunBinding
	host.add_child(rig)
	await process_frame
	var light := rig.get_directional_light()
	var presentation := rig.get_presentation()
	var unconfigured_audit := rig.audit()
	_check(
		rig.name == EmberAirlessSunBinding.RIG_NODE_NAME
			and rig.scene_file_path == EmberAirlessSunBinding.RIG_SCENE_PATH
			and rig.get_child_count() == 2
			and light != null and presentation != null,
		"standalone rig has the exact typed two-child authored topology",
	)
	_check(
		rig.find_children("*", "DirectionalLight3D", true, false).size() == 1
			and rig.find_children("*", "Light3D", true, false).size() == 1
			and rig.find_children("*", "WorldEnvironment", true, false).is_empty()
			and rig.find_children("*", "Camera3D", true, false).is_empty()
			and rig.find_children("*", "AudioStreamPlayer", true, false).is_empty(),
		"rig authors one light and no atmosphere, camera, or audio target",
	)
	_check(
		light.transform == EmberAirlessSunBinding.AUTHORED_LIGHT_TRANSFORM
			and (-light.global_transform.basis.z).is_equal_approx(
				EmberAirlessSunBinding.AUTHORED_EMITTED_LIGHT_DIRECTION
			)
			and EmberAirlessSunBinding.AUTHORED_BODY_TO_SUN_DIRECTION == Vector3.UP
			and EmberAirlessSunBinding.AUTHORED_EMITTED_LIGHT_DIRECTION \
			== -EmberAirlessSunBinding.AUTHORED_BODY_TO_SUN_DIRECTION,
		"immutable +Y body-to-sun direction is paired with exact -Y emitted rays",
	)
	_check(
		light.light_energy == EmberAirlessSunBinding.AUTHORED_BASELINE_ENERGY
			and light.light_color == EmberAirlessSunBinding.AUTHORED_BASELINE_COLOR
			and not light.shadow_enabled
			and is_equal_approx(
				light.shadow_opacity,
				EmberAirlessSunBinding.SURFACE_SHADOW_MAX_OPACITY
			)
			and light.directional_shadow_mode \
			== DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			and is_equal_approx(
				light.directional_shadow_max_distance,
				EmberAirlessSunBinding.SURFACE_SHADOW_MAX_DISTANCE_M
			),
		"authored airless display and bounded surface-shadow recipe are exact",
	)
	_check(
		not rig.is_processing() and not rig.is_physics_processing()
			and not rig.has_method(&"_process")
			and not rig.has_method(&"_physics_process")
			and rig.get_generation() == 0,
		"standalone binding is inert and owns no automatic cadence",
	)
	var unconfigured_errors := unconfigured_audit.get(
		"errors", PackedStringArray()
	) as PackedStringArray
	_check(
		not bool(unconfigured_audit.get("valid", true))
			and unconfigured_errors == PackedStringArray(["binding_not_configured"])
			and not bool(unconfigured_audit.get("production_caller_wired", true)),
		"standalone audit distinguishes an authored rig from absent production wiring",
	)
	host.queue_free()
	await process_frame


func _test_exact_configuration_and_airless_mapping() -> void:
	var fixture := await _fixture()
	if fixture.is_empty():
		return
	var rig := fixture.rig as EmberAirlessSunBinding
	var bootstrap := fixture.bootstrap as EmberMoonStreamingBootstrap
	var frame := fixture.frame as PlanetaryCoordinateFrame
	var loaded := fixture.loaded as EmberMoonAuthoredScene
	var light := rig.get_directional_light()
	var duplicate_world := EMBER_WORLD.duplicate(true) as PlanetaryWorldDefinition
	_check(
		rig.configure(duplicate_world, bootstrap, frame, loaded, 2, 1).reason
		== &"unexpected_world_definition",
		"configuration requires the exact canonical Ember world resource identity",
	)
	_check(
		rig.configure(EMBER_WORLD, bootstrap, frame, loaded, 2.0, 1).reason
		== &"invalid_coordinate_frame_generation"
			and rig.configure(EMBER_WORLD, bootstrap, frame, loaded, 2, 1.0).reason
			== &"invalid_location_generation",
		"configuration generations must be exact positive integers",
	)
	_check(
		rig.configure(EMBER_WORLD, bootstrap, frame, loaded, 1, 1).reason
		== &"stale_coordinate_frame_generation"
			and rig.configure(EMBER_WORLD, bootstrap, frame, loaded, 2, 2).reason
			== &"bootstrap_identity_mismatch",
		"stale frame and forged location generations fail before adapter mutation",
	)
	_check(
		rig.configure(EMBER_WORLD, bootstrap, null, loaded, 2, 1).reason
		== &"coordinate_frame_unavailable"
			and rig.configure(EMBER_WORLD, bootstrap, frame, null, 2, 1).reason
			== &"loaded_root_unavailable",
		"missing frame or loaded root identities fail closed",
	)
	light.light_energy = 2.0
	_check(
		rig.configure(EMBER_WORLD, bootstrap, frame, loaded, 2, 1).reason
		== &"authored_light_baseline_drift",
		"configuration rejects a target that no longer matches the authored baseline",
	)
	light.light_energy = EmberAirlessSunBinding.AUTHORED_BASELINE_ENERGY
	var configured := rig.configure(EMBER_WORLD, bootstrap, frame, loaded, 2, 1)
	var snapshot := rig.get_snapshot()
	var identity := snapshot.get("identity", {}) as Dictionary
	var policy := rig.get_presentation().get_policy_snapshot()
	_check(
		configured.accepted and rig.get_generation() == 1
			and int(configured.presentation_generation) == 1
			and int(configured.coordinate_frame_generation) == 2
			and int(configured.location_generation) == 1,
		"exact live Ember identities configure binding and presentation generation one",
	)
	_check(
		identity.world_id == &"ember_moon" and identity.body_id == &"ember_body"
			and identity.location_id == &"ember_moon"
			and int(identity.bootstrap_instance_id) == bootstrap.get_instance_id()
			and int(identity.loaded_root_instance_id) == loaded.get_instance_id()
			and int(identity.coordinate_frame_instance_id) == frame.get_instance_id(),
		"snapshot freezes exact world/body/bootstrap/root/frame identities as IDs",
	)
	_check(
		policy.world_id == &"ember_moon" and not bool(policy.has_atmosphere)
			and policy.atmosphere_profile_id == &""
			and int(policy.source_atmosphere_schema_version) == 0,
		"composition selects the existing policy's exact airless null-profile branch",
	)
	var north_observer := Vector3.UP * EmberAirlessSunBinding.BODY_RADIUS_M
	var day := rig.present_post_rebase_observation(north_observer, 2, 1, 1)
	_check(
		day.accepted and day.renderer_values == {
			"light_color": EmberAirlessSunBinding.AUTHORED_BASELINE_COLOR,
			"light_energy": EmberAirlessSunBinding.AUTHORED_BASELINE_ENERGY,
		}
			and light.light_color == EmberAirlessSunBinding.AUTHORED_BASELINE_COLOR
			and light.light_energy == EmberAirlessSunBinding.AUTHORED_BASELINE_ENERGY
			and light.shadow_enabled
			and is_equal_approx(
				light.shadow_opacity,
				EmberAirlessSunBinding.SURFACE_SHADOW_MAX_OPACITY
			),
		"north-pole airless daylight adds bounded hard surface shadows",
	)
	var south_observer := Vector3.DOWN * EmberAirlessSunBinding.BODY_RADIUS_M
	var night := rig.present_post_rebase_observation(south_observer, 2, 1, 1)
	_check(
		night.accepted and night.renderer_values.light_energy == 0.0
			and night.renderer_values.light_color \
			== EmberAirlessSunBinding.AUTHORED_BASELINE_COLOR
			and light.light_energy == 0.0
			and not light.shadow_enabled and light.shadow_opacity == 0.0,
		"south-pole airless night is exact zero energy and zero shadow",
	)
	var high_day := rig.present_post_rebase_observation(
		Vector3.UP * (
			EmberAirlessSunBinding.BODY_RADIUS_M
			+ EmberAirlessSunBinding.SURFACE_SHADOW_ALTITUDE_CEILING_M
		), 2, 1, 1
	)
	var mid_day := rig.present_post_rebase_observation(
		Vector3.UP * (
			EmberAirlessSunBinding.BODY_RADIUS_M
			+ EmberAirlessSunBinding.SURFACE_SHADOW_ALTITUDE_CEILING_M * 0.5
		), 2, 1, 1
	)
	var hard_horizon := rig.present_post_rebase_observation(
		Vector3.RIGHT * EmberAirlessSunBinding.BODY_RADIUS_M, 2, 1, 1
	)
	_check(
		high_day.accepted and high_day.renderer_values.light_energy \
			== EmberAirlessSunBinding.AUTHORED_BASELINE_ENERGY
			and not bool(high_day.surface_shadow.enabled)
			and high_day.surface_shadow.opacity == 0.0
			and mid_day.accepted and bool(mid_day.surface_shadow.enabled)
			and float(mid_day.surface_shadow.opacity) > 0.0
			and float(mid_day.surface_shadow.opacity) \
			< EmberAirlessSunBinding.SURFACE_SHADOW_MAX_OPACITY
			and hard_horizon.accepted
			and hard_horizon.renderer_values.light_energy == 0.0
			and not bool(hard_horizon.surface_shadow.enabled)
			and hard_horizon.surface_shadow.fog_factor_unitless == 0.0
			and hard_horizon.surface_shadow.cloud_factor_unitless == 0.0
			and hard_horizon.surface_shadow.wind_factor_unitless == 0.0,
		"altitude fade and hard day-angle horizon preserve the airless contract",
	)
	var before_rejections := rig.get_snapshot()
	var before_renderer := _renderer_values(light)
	_check(
		rig.present_post_rebase_observation(north_observer, 2, 1, 2).reason
		== &"stale_binding_generation"
			and rig.present_post_rebase_observation(north_observer, 2.0, 1, 1).reason
			== &"invalid_coordinate_frame_generation"
			and rig.present_post_rebase_observation(north_observer, 2, 1.0, 1).reason
			== &"invalid_location_generation",
		"binding, frame, and location generations remain separate exact integers",
	)
	_check(
		rig.present_post_rebase_observation(Vector3(NAN, 0.0, 0.0), 2, 1, 1).reason
		== &"invalid_body_local_observer"
			and rig.present_post_rebase_observation(Vector3.ZERO, 2, 1, 1).reason
			== &"sun_presentation_rejected",
		"invalid and policy-rejected body-local observations remain structured red",
	)
	_check(
		rig.get_snapshot() == before_rejections
			and _renderer_values(light) == before_renderer,
		"rejected observations preserve binding and renderer state exactly",
	)
	var authored_transform := light.transform
	light.shadow_enabled = false
	light.shadow_opacity = 0.125
	light.light_cull_mask = 0x0000FFFF
	light.light_indirect_energy = 0.375
	var caller_mask := light.light_cull_mask
	var caller_indirect := light.light_indirect_energy
	var day_again := rig.present_post_rebase_observation(north_observer, 2, 1, 1)
	_check(
		day_again.accepted and light.transform == authored_transform
			and light.shadow_enabled
			and is_equal_approx(
				light.shadow_opacity,
				EmberAirlessSunBinding.SURFACE_SHADOW_MAX_OPACITY
			)
			and light.light_cull_mask == caller_mask
			and light.light_indirect_energy == caller_indirect,
		"presentation repairs its shadow envelope without taking adjacent light authority",
	)
	light.light_energy = 0.25
	light.light_color = Color(0.1, 0.2, 0.3, 1.0)
	var repaired := rig.present_post_rebase_observation(north_observer, 2, 1, 1)
	_check(
		repaired.accepted and repaired.reason == &"renderer_reapplied"
			and _renderer_values(light) == repaired.renderer_values,
		"duplicate caller observation delegates exact two-property drift repair",
	)
	var hostile_callback_called := [false]
	var callback := func(_reason: StringName, _state: Dictionary) -> void:
		hostile_callback_called[0] = true
		(fixture.host as Node).remove_child(rig)
	rig.get_presentation().presentation_committed.connect(callback)
	var before_hostile := rig.get_snapshot()
	var before_hostile_renderer := _renderer_values(light)
	var signalled := rig.present_post_rebase_observation(south_observer, 2, 1, 1)
	rig.get_presentation().presentation_committed.disconnect(callback)
	_check(
		signalled.reason == &"sun_presentation_signal_observer_present"
			and not bool(hostile_callback_called[0])
			and rig.get_parent() == fixture.host
			and rig.get_snapshot() == before_hostile
			and _renderer_values(light) == before_hostile_renderer,
		"external adapter signal observers reject before hostile composition mutation",
	)
	await _cleanup_fixture(fixture)


func _test_generation_rebase_and_lifecycle() -> void:
	var fixture := await _fixture(true)
	if fixture.is_empty():
		return
	var rig := fixture.rig as EmberAirlessSunBinding
	var bootstrap := fixture.bootstrap as EmberMoonStreamingBootstrap
	var frame := fixture.frame as PlanetaryCoordinateFrame
	var loaded := fixture.loaded as EmberMoonAuthoredScene
	var light := rig.get_directional_light()
	var observer := Vector3.DOWN * EmberAirlessSunBinding.BODY_RADIUS_M
	rig.present_post_rebase_observation(observer, 2, 1, 1)
	var before_pending := rig.get_snapshot()
	var before_pending_renderer := _renderer_values(light)
	var pending := frame.request_rebase(Vector3(11_000.0, 0.0, 0.0), 2)
	_check(
		pending.accepted
			and rig.present_post_rebase_observation(observer, 2, 1, 1).reason
			== &"coordinate_frame_rebase_pending"
			and rig.get_snapshot() == before_pending
			and _renderer_values(light) == before_pending_renderer,
		"pending origin transaction blocks presentation without state or light writes",
	)
	frame.cancel_rebase(int(pending.request.request_id), 2)
	var request := frame.request_rebase(Vector3(11_000.0, 0.0, 0.0), 2)
	bootstrap.position += request.request.world_translation_delta
	rig.position += request.request.world_translation_delta
	var commit := frame.commit_rebase(int(request.request.request_id), 2)
	_check(
		commit.accepted and frame.get_generation() == 3
			and loaded.global_position == Vector3(-11_000.0, 0.0, 0.0),
		"caller-owned common translation and frame commit establish generation three",
	)
	var stale := rig.present_post_rebase_observation(observer, 2, 1, 1)
	var future := rig.present_post_rebase_observation(observer, 4, 1, 1)
	var current := rig.present_post_rebase_observation(observer, 3, 1, 1)
	_check(
		stale.reason == &"stale_coordinate_frame_generation"
			and future.reason == &"stale_coordinate_frame_generation"
			and current.accepted
			and int(current.coordinate_frame_generation) == 3,
		"stale N and forged N+2 reject while exact post-rebase N+1 succeeds",
	)
	_check(
		rig.get_generation() == 1
			and rig.get_presentation().get_generation() == 1
			and rig.get_snapshot().last_body_local_observer_m == observer,
		"rebase advances only frame generation and preserves binding, adapter, and body-local observation",
	)
	var original_root_transform := loaded.transform
	loaded.position += Vector3.RIGHT
	_check(
		rig.present_post_rebase_observation(observer, 3, 1, 1).reason
		== &"loaded_root_local_transform_drift",
		"loaded body-root transform drift fails before renderer dispatch",
	)
	loaded.transform = original_root_transform
	loaded.set_meta(&"world_location_generation", 7)
	_check(
		rig.present_post_rebase_observation(observer, 3, 1, 1).reason
		== &"stale_location_generation",
		"live root metadata drift cannot counterfeit the bound location generation",
	)
	loaded.set_meta(&"world_location_generation", 1)
	var authored_light_transform := light.transform
	light.rotate_y(0.1)
	_check(
		rig.present_post_rebase_observation(observer, 3, 1, 1).reason
		== &"authored_light_orientation_drift",
		"runtime light orientation drift is rejected rather than repaired or adopted",
	)
	light.transform = authored_light_transform
	var host := fixture.host as Node3D
	host.remove_child(rig)
	await process_frame
	_check(
		light.light_energy == EmberAirlessSunBinding.AUTHORED_BASELINE_ENERGY
			and rig.present_post_rebase_observation(observer, 3, 1, 1).reason
			== &"rig_unavailable",
		"rig exit restores baseline and detached binding rejects observation",
	)
	host.add_child(rig)
	await process_frame
	_check(
		light.light_energy == 0.0
			and rig.present_post_rebase_observation(observer, 3, 1, 1).accepted,
		"rig re-entry reapplies retained night state without advancing any generation",
	)
	await _cleanup_fixture(fixture)


func _test_unload_replacement_and_reports() -> void:
	var fixture := await _fixture(true)
	if fixture.is_empty():
		return
	var host := fixture.host as Node3D
	var rig := fixture.rig as EmberAirlessSunBinding
	var bootstrap := fixture.bootstrap as EmberMoonStreamingBootstrap
	var frame := fixture.frame as PlanetaryCoordinateFrame
	var loaded := fixture.loaded as EmberMoonAuthoredScene
	var observer := Vector3.UP * EmberAirlessSunBinding.BODY_RADIUS_M
	rig.present_post_rebase_observation(observer, 2, 1, 1)
	var far := _absolute(
		frame,
		Vector3(0.0, 300_001.0, 0.0),
		2,
	)
	var unload := bootstrap.update_absolute_focus(far, 2)
	_check(
		unload.accepted and unload.location_generation == 2
			and bootstrap.get_loaded_instance() == null
			and rig.present_post_rebase_observation(observer, 2, 1, 1).reason
			== &"loaded_root_unavailable",
		"unload retires the exact root identity before queued content can be reused",
	)
	await process_frame
	var body_coordinate := NearbySectorOrbitalRegistry.new().get_coordinate(
		NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID
	)
	var reload := bootstrap.update_absolute_focus(body_coordinate, 2)
	await process_frame
	await process_frame
	var replacement := bootstrap.get_loaded_instance() as EmberMoonAuthoredScene
	_check(
		reload.accepted and reload.location_generation == 3
			and replacement != null and replacement != loaded
			and int(replacement.get_meta(&"world_location_generation", -1)) == 3,
		"reload produces a distinct live root at exact location generation three",
	)
	_check(
		rig.present_post_rebase_observation(observer, 2, 3, 1).reason
		== &"loaded_root_unavailable",
		"old binding cannot adopt a replacement root even with its current generation",
	)
	rig.queue_free()
	await process_frame
	var replacement_rig := RIG_SCENE.instantiate() as EmberAirlessSunBinding
	host.add_child(replacement_rig)
	await process_frame
	var replacement_configure := replacement_rig.configure(
		EMBER_WORLD,
		bootstrap,
		frame,
		replacement,
		2,
		3,
	)
	_check(
		replacement_configure.accepted
			and replacement_rig.present_post_rebase_observation(observer, 2, 3, 1).accepted,
		"replacement root requires and accepts a fresh standalone rig identity",
	)
	var audit := replacement_rig.audit()
	var authority := audit.get("authority", {}) as Dictionary
	var adjacent := audit.get("adjacent_authority", {}) as Dictionary
	var capabilities := audit.get("capabilities", {}) as Dictionary
	_check(
		audit.valid and authority.size() == 12 and bool(authority.renderer)
			and _all_other_authority_false(authority, "renderer")
			and _all_boolean_false(adjacent),
		"configured binding audits exact renderer-only and zero adjacent authority",
	)
	_check(
		bool(capabilities.authored_airless_directional_light_target)
			and bool(capabilities.immutable_body_to_sun_direction)
			and bool(capabilities.immutable_light_orientation)
			and bool(capabilities.baseline_relative_sun_presentation)
			and bool(capabilities.post_rebase_generation_validation)
			and bool(capabilities.exact_streamed_root_identity_validation)
			and bool(capabilities.caller_driven_observations_only)
			and not bool(capabilities.production_caller_wired)
			and not bool(capabilities.runtime_target_creation)
			and not bool(capabilities.runtime_orientation_mutation)
			and not bool(capabilities.coordinate_conversion)
			and not bool(capabilities.clock_or_ephemeris)
			and not bool(capabilities.atmosphere)
			and bool(capabilities.shadow_or_occlusion),
		"capabilities include bounded airless surface shadows without adjacent authority",
	)
	var report := replacement_rig.get_audit_report()
	var mutable_snapshot := replacement_rig.get_snapshot()
	(mutable_snapshot.identity as Dictionary)["world_id"] = &"forged"
	(mutable_snapshot.authored as Dictionary)["body_to_sun_direction"] = Vector3.RIGHT
	(mutable_snapshot.presentation as Dictionary).clear()
	(report.snapshot as Dictionary).clear()
	var fresh := replacement_rig.get_snapshot()
	_check(
		fresh.identity.world_id == &"ember_moon"
			and fresh.authored.body_to_sun_direction == Vector3.UP
			and not (fresh.presentation as Dictionary).is_empty()
			and not (replacement_rig.get_audit_report().snapshot as Dictionary).is_empty(),
		"snapshot and audit results are deeply detached",
	)
	_check(
		not _contains_live_object(replacement_rig.get_snapshot())
			and not _contains_live_object(replacement_rig.get_audit_report()),
		"reports expose detached values and instance IDs without live objects",
	)
	var main_text := FileAccess.get_file_as_string("res://scenes/main.tscn")
	_check(
		not main_text.contains(EmberAirlessSunBinding.RIG_SCENE_PATH)
			and not main_text.contains("EmberAirlessSunBinding"),
		"foundation intentionally leaves the production Main caller unwired",
	)
	await _cleanup_fixture(fixture)


func _fixture(configure_binding: bool = false) -> Dictionary:
	var host := Node3D.new()
	host.name = "SunBindingFixture"
	root.add_child(host)
	var bootstrap := BOOTSTRAP_SCENE.instantiate() as EmberMoonStreamingBootstrap
	var rig := RIG_SCENE.instantiate() as EmberAirlessSunBinding
	host.add_child(bootstrap)
	host.add_child(rig)
	await process_frame
	await process_frame
	var frame := bootstrap.get_coordinate_frame_for_session()
	if frame == null:
		_fixture_failed("fixture bootstrap did not expose a coordinate frame")
		host.queue_free()
		return {}
	var request := frame.request_rebase(bootstrap.position, 1)
	if not bool(request.get("accepted", false)):
		_fixture_failed("fixture could not request initial Ember rebase")
		host.queue_free()
		return {}
	bootstrap.position += request.request.world_translation_delta
	rig.position += request.request.world_translation_delta
	var commit := frame.commit_rebase(int(request.request.request_id), 1)
	var body_coordinate := NearbySectorOrbitalRegistry.new().get_coordinate(
		NearbySectorOrbitalRegistry.EMBER_BODY_CENTER_ID
	)
	var load := bootstrap.update_absolute_focus(body_coordinate, 2)
	await process_frame
	await process_frame
	var loaded := bootstrap.get_loaded_instance() as EmberMoonAuthoredScene
	if not bool(commit.get("accepted", false)) \
			or not bool(load.get("accepted", false)) \
			or loaded == null:
		_fixture_failed("fixture could not establish loaded Ember generation one")
		host.queue_free()
		return {}
	var fixture := {
		"host": host,
		"bootstrap": bootstrap,
		"frame": frame,
		"loaded": loaded,
		"rig": rig,
	}
	if configure_binding:
		var configured := rig.configure(
			EMBER_WORLD,
			bootstrap,
			frame,
			loaded,
			2,
			1,
		)
		if not bool(configured.get("accepted", false)):
			_fixture_failed("fixture could not configure Ember airless sun binding")
			host.queue_free()
			return {}
	return fixture


func _absolute(
		frame: PlanetaryCoordinateFrame,
		body_local: Vector3,
		generation: int,
	) -> Dictionary:
	var result := frame.body_local_to_orbital_position(body_local, generation)
	return (result.get("coordinate", {}) as Dictionary).duplicate(true)


func _renderer_values(light: DirectionalLight3D) -> Dictionary:
	return {
		"light_color": light.light_color,
		"light_energy": light.light_energy,
	}.duplicate(true)


func _all_other_authority_false(authority: Dictionary, positive_key: String) -> bool:
	for key: Variant in authority:
		if authority[key] is not bool:
			return false
		if str(key) == positive_key:
			if not bool(authority[key]):
				return false
		elif bool(authority[key]):
			return false
	return true


func _all_boolean_false(values: Dictionary) -> bool:
	if values.is_empty():
		return false
	for key: Variant in values:
		if values[key] is not bool or bool(values[key]):
			return false
	return true


func _contains_live_object(value: Variant) -> bool:
	if value is Object or value is WeakRef or value is Callable or value is Signal:
		return true
	if value is Dictionary:
		for key: Variant in value as Dictionary:
			if _contains_live_object(key) \
					or _contains_live_object((value as Dictionary)[key]):
				return true
	elif value is Array:
		for item: Variant in value as Array:
			if _contains_live_object(item):
				return true
	return false


func _cleanup_fixture(fixture: Dictionary) -> void:
	var host := fixture.get("host") as Node
	if is_instance_valid(host):
		host.queue_free()
	await process_frame
	await process_frame


func _fixture_failed(message: String) -> void:
	_failures.append(message)
	push_error("FIXTURE FAIL: %s" % message)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	_check(
		_assertions == EXPECTED_ASSERTIONS - 1,
		"the focused assertion roster remains exact",
	)
	print("EMBER_AIRLESS_SUN_BINDING_TEST_ASSERTIONS: %d" % _assertions)
	if _failures.is_empty():
		print("EMBER_AIRLESS_SUN_BINDING_TEST_OK")
		quit(0)
		return
	print("EMBER_AIRLESS_SUN_BINDING_TEST_FAILURES: %s" % _failures)
	quit(1)
