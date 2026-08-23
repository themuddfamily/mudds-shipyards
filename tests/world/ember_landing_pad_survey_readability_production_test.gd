extends SceneTree

const BindingScript := preload(
	"res://scripts/world/ember_planetary_surface_production_binding.gd"
)
const EmberScene := preload("res://scenes/world/planets/ember_moon.tscn")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const RELAY_ANCHOR := Vector3(180.0, 120009.0, -44.0)
const RETURN_ANCHOR := Vector3(540.0, 120030.0, -210.0)

class FakeHost:
	var generation := 52
	var attachment_generation := 1
	var player_instance_id := 0
	var loaded_scene_instance_id := 0
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop",
			"attached": true,
			"phase_id": &"on_foot",
			"loaded_scene_instance_id": loaded_scene_instance_id,
			"identities": {
				"world_id": &"ember_moon",
				"player_instance_id": player_instance_id,
			},
		}

var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var authored_scene := EmberScene.instantiate() as Node3D
	root.add_child(authored_scene)
	var actor := Node3D.new()
	root.add_child(actor)
	var director := DirectorScript.new()
	root.add_child(director)
	var host := FakeHost.new()
	host.player_instance_id = actor.get_instance_id()
	host.loaded_scene_instance_id = authored_scene.get_instance_id()
	var binding := BindingScript.new() as Node
	root.add_child(binding)
	await process_frame

	var guides := authored_scene.get_node(
		^"LandingRegion/SurfaceLandmarks/PadGuideVisuals"
	) as MultiMeshInstance3D
	var authored := guides.get_meta("authored_transforms", []) as Array
	var configured: Dictionary = binding.call(
		&"configure", host, director, Callable(self, "_reward_sink"), 52
	)
	var available := binding.call(&"get_snapshot") as Dictionary
	var availability := (
		available.relay_survey_presentation.landing_pad_survey_status as Dictionary
	)
	var available_transforms := _guide_transforms(guides)
	_check(
		bool(configured.accepted)
			and availability.state == &"survey_available"
			and availability.silhouette == &"inward_canted_tall_pair"
			and bool(availability.color_independent)
			and int(availability.loaded_scene_instance_id) \
				== authored_scene.get_instance_id()
			and available_transforms.size() == 2
			and available_transforms[0].origin == authored[0].origin
			and available_transforms[1].origin == authored[1].origin
			and available_transforms[0].basis.is_equal_approx(
				Basis(Vector3.RIGHT, 0.34).scaled(Vector3(1.0, 1.28, 1.0))
			)
			and available_transforms[1].basis.is_equal_approx(
				Basis(Vector3.RIGHT, -0.34).scaled(Vector3(1.0, 1.28, 1.0))
			),
		"ready survey is visible from the pad as a tall inward-canted guide pair"
	)

	var started: Dictionary = binding.call(&"start_relay_survey")
	var objective := binding.get_node("OwnedRelaySurveyPresentation") as Node3D
	var relay_marker := objective.get_node("OwnedRelaySurveyMarker") as MeshInstance3D
	var return_marker := objective.get_node("OwnedReturnSurveyMarker") as MeshInstance3D
	var interaction := binding.get_node("OwnedSurveyBunkerInteraction")
	var active := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(started.accepted)
			and active.relay_survey_presentation.landing_pad_survey_status.state \
				== &"survey_in_progress"
			and _guide_transforms(guides) == authored
			and relay_marker.visible and not return_marker.visible
			and active.relay_survey_presentation.mandatory_checkpoint_progress.state \
				== &"relay_checkpoint_pending",
		"starting restores neutral guides while retaining the 0/2 relay cue"
	)

	var logged: Dictionary = interaction.call(
		&"submit_interaction", actor, 52, 1
	)
	var optional_relay := binding.call(&"get_snapshot") as Dictionary
	var reached_relay: Dictionary = binding.call(
		&"submit_relay_survey_position", RELAY_ANCHOR
	)
	var optional_return := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(logged.accepted)
			and optional_relay.relay_survey_presentation.route_direction.target_id \
				== &"ember_relay_tower"
			and bool(reached_relay.accepted)
			and optional_return.relay_survey_presentation.route_direction.target_id \
				== &"ember_return_beacon"
			and optional_return.relay_survey_presentation.mandatory_checkpoint_progress.state \
				== &"relay_reached_return_pending"
			and relay_marker.visible and return_marker.visible
			and _guide_transforms(guides) == authored,
		"optional-return pointer and accepted checkpoint geometry remain intact"
	)

	var detached_active: Dictionary = binding.call(&"detach")
	var detached_snapshot := binding.call(&"get_snapshot") as Dictionary
	var detached_neutral := _guide_transforms(guides)
	host.attachment_generation = 2
	var reentered_active: Dictionary = binding.call(&"reenter")
	var retained_active := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(detached_active.accepted)
			and detached_neutral == authored
			and not bool(
				detached_snapshot.relay_survey_presentation.landing_pad_survey_status.visible
			)
			and bool(reentered_active.accepted)
			and retained_active.relay_survey_presentation.route_direction.target_id \
				== &"ember_return_beacon"
			and return_marker.visible
			and _guide_transforms(guides) == authored,
		"detach clears pad state and same-run re-entry restores return cues"
	)

	var reached_return: Dictionary = binding.call(
		&"submit_relay_survey_position", RETURN_ANCHOR
	)
	var awaiting := binding.call(&"get_snapshot") as Dictionary
	var completed_transforms := _guide_transforms(guides)
	_check(
		bool(reached_return.accepted)
			and awaiting.relay_survey_presentation.landing_pad_survey_status.state \
				== &"completed_return"
			and awaiting.relay_survey_presentation.landing_pad_survey_status.silhouette \
				== &"lowered_horizontal_pair"
			and completed_transforms[0].basis.is_equal_approx(
				Basis(Vector3.RIGHT, PI * 0.5)
			)
			and completed_transforms[1].basis.is_equal_approx(
				Basis(Vector3.RIGHT, -PI * 0.5)
			)
			and awaiting.relay_survey_presentation.completion_response.state \
				== &"route_complete_pending_reward"
			and not bool(awaiting.relay_survey_presentation.route_direction.active),
		"accepted return lowers both pad guides without replacing completion cues"
	)

	var committed: Dictionary = binding.call(&"commit_relay_survey_reward")
	var rewarded := binding.call(&"get_snapshot") as Dictionary
	var detached_complete: Dictionary = binding.call(&"detach")
	var complete_detach_neutral := _guide_transforms(guides)
	host.attachment_generation = 3
	var reentered_complete: Dictionary = binding.call(&"reenter")
	var restored_complete := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(committed.accepted) and _reward_calls == 1
			and rewarded.relay_survey_presentation.completion_response.state \
				== &"reward_confirmed"
			and bool(detached_complete.accepted) and complete_detach_neutral == authored
			and bool(reentered_complete.accepted)
			and restored_complete.relay_survey_presentation.landing_pad_survey_status.state \
				== &"completed_return"
			and _guide_transforms(guides) == completed_transforms
			and restored_complete.relay_survey_presentation.completion_response.state \
				== &"reward_confirmed",
		"completed-return guides survive same-run re-entry and reward confirmation"
	)

	var next_run: Dictionary = binding.call(&"start_relay_survey")
	var reset := binding.call(&"get_snapshot") as Dictionary
	var reset_pad := reset.relay_survey_presentation.landing_pad_survey_status as Dictionary
	_check(
		bool(next_run.accepted)
			and reset_pad.state == &"survey_in_progress"
			and _guide_transforms(guides) == authored
			and reset.relay_survey_presentation.mandatory_checkpoint_progress.activity_generation \
				== 2
			and reset.relay_survey_presentation.mandatory_checkpoint_progress.state \
				== &"relay_checkpoint_pending"
			and not bool(reset.relay_survey_presentation.route_direction.active)
			and not bool(reset.relay_survey_presentation.completion_response.visible),
		"new activity generation clears completed pad, pointer, and completion states"
	)

	var budget := reset_pad.incremental_budget as Dictionary
	_check(
		guides.multimesh.instance_count == 2
			and budget == {
				"nodes": 0, "multimeshes": 0, "mesh_instances": 0,
				"materials": 0, "triangles": 0,
			}
			and not bool(reset_pad.authority.activity)
			and not bool(reset_pad.authority.checkpoint)
			and not bool(reset_pad.authority.reward)
			and not bool(reset_pad.authority.navigation)
			and not bool(reset_pad.authority.movement)
			and not bool(reset_pad.authority.collision),
		"pad readability reuses exactly two guide instances with zero authority"
	)

	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("EMBER_LANDING_PAD_SURVEY_READABILITY_PRODUCTION_TEST_OK: %d assertions" % _assertions)
	quit(0)


func _guide_transforms(guides: MultiMeshInstance3D) -> Array:
	return (guides.get_meta("survey_presentation_transforms", []) as Array).duplicate()


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"test_reward"}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
