extends SceneTree

const BindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const RingScript := preload("res://scripts/world/planetary_orbital_approach_ring_presentation.gd")

class FakeHost:
	var generation := 8
	var attachment_generation := 1
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		return {"host_id": &"ember_surface_loop", "attached": true, "phase_id": &"on_foot", "identities": {"world_id": &"ember_moon"}}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var host := FakeHost.new()
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new()
	root.add_child(binding)
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 8)
	var solar := binding.submit_solar_observation(Vector3.UP, Vector3.DOWN, 0.0)
	var ring: Dictionary = binding.get_snapshot().orbital_ring
	var bound_ring := binding.get_node("OwnedOrbitalApproachRing/OwnedOrbitalApproachRing") as MeshInstance3D
	var comparison := RingScript.new() as Node3D
	root.add_child(comparison)
	var comparison_anchor := Vector3(41.0, 140000.0, -17.0)
	var comparison_configured: Dictionary = comparison.call(&"configure", comparison_anchor)
	var comparison_ring := comparison.get_node("OwnedOrbitalApproachRing") as MeshInstance3D
	var comparison_material := comparison_ring.material_override as StandardMaterial3D
	var first_frame_presentation_ready: bool = (
		comparison_ring.visible
		and is_equal_approx(comparison_material.emission_energy_multiplier, 0.15)
	)
	var comparison_solar: Dictionary = comparison.call(
		&"apply_solar_phase", {"sun_elevation_sine": 1.0}
	)
	var bound_material := bound_ring.material_override as StandardMaterial3D
	var resources_consolidated: bool = (
		bound_ring.mesh == comparison_ring.mesh
		and not bound_ring.mesh.resource_local_to_scene
		and bound_material != comparison_material
		and bound_material.emission_energy_multiplier != comparison_material.emission_energy_multiplier
	)
	var presentation_preserved: bool = (
		comparison.position == comparison_anchor
		and comparison_ring.transform == Transform3D.IDENTITY
		and comparison_ring.mesh is TorusMesh
		and (comparison_ring.mesh as TorusMesh).inner_radius == 18.0
		and (comparison_ring.mesh as TorusMesh).outer_radius == 20.0
		and comparison_material.emission == Color(0.2, 0.55, 1.0, 1.0)
		and comparison_ring.visible
		and (comparison.call(&"get_snapshot") as Dictionary).authority == {
			"navigation": false, "entry": false, "flight": false, "clock": false
		}
	)
	var comparison_low: Dictionary = comparison.call(&"apply_graphics_profile", &"low")
	var low_profile_hidden := not comparison_ring.visible
	var comparison_high: Dictionary = comparison.call(&"apply_graphics_profile", &"high")
	var comfort_and_authority_preserved: bool = (
		comparison_low.accepted
		and low_profile_hidden
		and comparison_high.accepted
		and comparison_ring.visible
		and not comparison.is_processing()
		and not comparison.is_physics_processing()
		and comparison.find_children("*", "CollisionObject3D", true, false).is_empty()
	)
	var detached := binding.detach()
	host.attachment_generation = 2
	var reentered := binding.reenter()
	var restored: Dictionary = binding.get_snapshot().orbital_ring
	if not configured.accepted or not solar.accepted or ring.anchor_body_local_m == Vector3.ZERO \
			or not comparison_configured.accepted or not comparison_solar.accepted \
			or not first_frame_presentation_ready or not resources_consolidated or not presentation_preserved \
			or not comfort_and_authority_preserved \
			or not ring.visible or not detached.accepted or not reentered.accepted \
			or not restored.visible or restored.authority.entry:
		push_error("orbital approach ring production lifecycle failed")
		quit(1)
		return
	print("EMBER_ORBITAL_APPROACH_RING_PRODUCTION_BINDING_TEST_OK: lifecycle; 2 ring copies use 1 mesh resource")
	quit(0)

func _reward_sink(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true, "reason": &"test_reward"}
