extends SceneTree

## Component contract for one berth-state display, including the colour-vision
## and shape channels that make its three lease states readable.
##
## Why the colour floors below. The cue used to signal lease state with colour
## alone, in cyan / amber / green. Measured through the shared
## sRGB -> Viénot -> CIE L*a*b* -> CIEDE2000 chain in tests/fleet_colour_metrics.gd,
## the released/occupied pair scored 27.72 in normal vision, 22.63 under
## protanopia, 18.38 under deuteranopia and 2.77 under tritanopia. CIEDE2000 is
## scaled so ~2.3 is the practical just-noticeable difference for two patches
## held side by side, so the tritan number was not a marginal deficiency: an open
## berth and an occupied one were the same colour. The audited defect is asserted
## below as still failing this suite's own gate, so the floors are demonstrably
## discriminating rather than decorative.
##
## The floors are set well above the HUD's own MINIMUM_STATE_SEPARATION of 24.0
## for the emissive cue, because that cue is read across a hangar deck at a
## glance rather than compared side by side, and because the emissive product is
## clipped and tonemapped before a player sees it, which compresses authored
## differences. Albedo and label floors sit at the HUD's 24.0: the albedo is only
## the unlit fallback and the label carries its own text channel besides.
##
## Colour is never the only channel. The shape assertions freeze a second,
## non-colour cue — a deck glyph whose silhouette encodes the state — so the
## three states stay separable in a fully desaturated frame.

const FEEDBACK_SCENE := preload("res://scenes/world/components/ship_berth_feedback.tscn")
const BERTH_SCENE := preload("res://scenes/world/components/ship_berth.tscn")
const TORRENT_DEFINITION := preload("res://assets/ships/torrent_provisional.tres")
# One implementation of the perceptual maths, shared with the fleet colour audit
# and with the design probe that chose this palette.
const ColourMetrics := preload("res://tests/fleet_colour_metrics.gd")

const CUE_STATES: Array[StringName] = [&"released", &"approach", &"occupied"]
const CUE_EMISSION_FLOOR := 38.0
const CUE_ALBEDO_FLOOR := 24.0
const CUE_LABEL_FLOOR := 24.0
# The pre-fix triad, kept as a structured negative control. It must fail the same
# gate under the same maths, in every vision model, or the floors prove nothing.
const AUDITED_DEFECT_EMISSION := {
	&"released": "33f0ff",
	&"approach": "ff8c1f",
	&"occupied": "47ffa6",
}
const EXPECTED_GLYPH_IDS := {
	&"released": &"gate_open",
	&"approach": &"approach_chevron",
	&"occupied": &"secured_bar",
}

var _failures: Array[String] = []
var _assertions := 0
var _reentry_berth: ShipBerth
var _reentry_feedback: ShipBerthFeedback
var _reentry_ship: Node3D
var _reentry_listener_a: Array[Dictionary] = []
var _reentry_listener_b: Array[Dictionary] = []
var _reentry_occupy_results: Array[bool] = []
var _weak_reconcile_states: Array[StringName] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var berth := BERTH_SCENE.instantiate() as ShipBerth
	berth.berth_id = &"feedback_test_berth"
	stage.add_child(berth)
	var feedback := FEEDBACK_SCENE.instantiate() as ShipBerthFeedback
	feedback.cue_half_width = 6.0
	feedback.cue_half_length = 8.0
	berth.add_child(feedback)
	await process_frame

	_check(feedback != null and feedback.get_component_id() == &"ship_berth_feedback", "typed feedback scene exposes stable component identity")
	_check(feedback.get_parent() == berth and feedback.is_in_group(&"ship_berth_feedback"), "feedback binds only to its direct authoritative ShipBerth")
	_check(feedback.get_feedback_state() == &"released", "fresh unclaimed berth renders released state")
	_check(bool(feedback.get_audit_report().valid), "fresh component passes its complete audit")
	var perf := feedback.get_performance_report()
	# All sixteen named/stateful copies and submissions remain. Seven exact size
	# recipes replace sixteen one-use BoxMeshes: copy roster 4,4,2,2,2,1,1.
	_check(
		int(perf.owned_nodes) == 19
		and int(perf.mesh_instances) == 16
		and int(perf.drawn_copies) == 16
		and int(perf.render_submissions) == 16
		and int(perf.material_resources) == 4,
		"component preserves nineteen nodes, sixteen named copies/submissions, and four instance-local materials"
	)
	_check(
		int(perf.mesh_resources_before_sharing) == 16
		and int(perf.mesh_resources) == 7
		and int(perf.mesh_resource_savings) == 9
		and bool(perf.mesh_sharing_exact)
		and perf.mesh_resource_copy_roster == [1, 1, 2, 2, 2, 4, 4],
		"component-local BoxMesh allocation is frozen at 16 -> 7 with the exact copy roster"
	)
	var boundary_port_forward := feedback.get_node(
		"FeedbackVisual/Boundary_Port_Forward"
	) as MeshInstance3D
	var boundary_port_aft := feedback.get_node(
		"FeedbackVisual/Boundary_Port_Aft"
	) as MeshInstance3D
	var boundary_starboard_forward := feedback.get_node(
		"FeedbackVisual/Boundary_Starboard_Forward"
	) as MeshInstance3D
	var boundary_starboard_aft := feedback.get_node(
		"FeedbackVisual/Boundary_Starboard_Aft"
	) as MeshInstance3D
	_check(
		boundary_port_forward.mesh == boundary_port_aft.mesh
		and boundary_port_forward.mesh == boundary_starboard_forward.mesh
		and boundary_port_forward.mesh == boundary_starboard_aft.mesh,
		"the four independent boundary nodes share their one exact build-frozen size recipe"
	)
	_check(int(perf.collision_nodes) == 0 and int(perf.lights) == 0 and int(perf.audio_nodes) == 0 and int(perf.particle_emitters) == 0, "feedback adds no collision, light, audio, or particle authority")
	_check(feedback.get_evidence_metadata().evidence_status == &"modern_interpretation" and not bool(feedback.get_evidence_metadata().historically_supported), "feedback remains an explicit unsupported modern interpretation")

	var ship := Node3D.new()
	ship.name = "LeaseOwner"
	stage.add_child(ship)
	var token := berth.try_reserve(ship, TORRENT_DEFINITION)
	await process_frame
	_check(not token.is_empty() and feedback.get_feedback_state() == &"approach", "real reservation transition renders approach state")
	_check(feedback.get_state_snapshot().label == "APPROACH VECTOR", "approach state publishes its exact visible label")
	_check(berth.occupy(ship, token), "fixture converts the exact opaque lease to occupancy")
	await process_frame
	_check(feedback.get_feedback_state() == &"occupied" and feedback.get_state_snapshot().label == "BERTH SECURED", "real occupancy transition renders secured state")
	_check(berth.release(ship, token), "fixture releases the authoritative occupied lease")
	await process_frame
	_check(feedback.get_feedback_state() == &"released", "real lease release restores open state")

	await _test_state_channels(berth, feedback, ship)

	feedback.set_auto_advance_enabled(false)
	feedback.seek_simulation(0.0)
	feedback.advance_simulation(0.25)
	_check(is_equal_approx(float(feedback.get_state_snapshot().elapsed), 0.25), "manual deterministic clock advances by exact elapsed time")
	var first_phase := float(feedback.get_state_snapshot().phase)
	feedback.seek_simulation(0.0)
	for _step in 30:
		feedback.advance_simulation(1.0 / 120.0)
	_check(absf(float(feedback.get_state_snapshot().phase) - first_phase) < 0.00001, "manual animation is invariant between one-step and 120 Hz subdivision")
	feedback.set_feedback_paused(true)
	feedback.advance_simulation(1.0)
	_check(absf(float(feedback.get_state_snapshot().elapsed) - 0.25) < 0.00001, "paused feedback rejects manual time advancement")
	feedback.set_feedback_paused(false)
	feedback.set_feedback_enabled(false)
	_check(not feedback.visible and int(feedback.get_performance_report().visible_meshes) == 0, "disabled lifecycle hides every presentation mesh")
	_check(bool(feedback.get_audit_report().valid), "disabled presentation remains a valid intentional lifecycle state")
	feedback.set_feedback_enabled(true)
	_check(bool(feedback.get_audit_report().valid), "re-enabled feedback restores a valid presentation")

	var berth_two := BERTH_SCENE.instantiate() as ShipBerth
	berth_two.berth_id = &"feedback_isolation_berth"
	stage.add_child(berth_two)
	var feedback_two := FEEDBACK_SCENE.instantiate() as ShipBerthFeedback
	berth_two.add_child(feedback_two)
	await process_frame
	var material_a := (feedback.get_node("FeedbackVisual/LeaseStatePlate") as MeshInstance3D).material_override
	var material_b := (feedback_two.get_node("FeedbackVisual/LeaseStatePlate") as MeshInstance3D).material_override
	_check(material_a != material_b, "two berth instances never share mutable presentation materials")
	var mesh_a := (feedback.get_node("FeedbackVisual/Boundary_Port_Forward") as MeshInstance3D).mesh
	var mesh_b := (feedback_two.get_node("FeedbackVisual/Boundary_Port_Forward") as MeshInstance3D).mesh
	_check(mesh_a != mesh_b, "component-local mesh sharing cannot leak a mutable test or runtime mutation between berths")
	var ship_two := Node3D.new()
	stage.add_child(ship_two)
	var token_two := berth_two.try_reserve(ship_two, TORRENT_DEFINITION)
	await process_frame
	_check(not token_two.is_empty() and feedback_two.get_feedback_state() == &"approach" and feedback.get_feedback_state() == &"released", "one berth state cannot bleed into another instance")
	berth_two.release(ship_two, token_two)
	ship_two.queue_free()

	# A listener may synchronously advance the authoritative lease while an outer
	# feedback event is still being delivered. Both listeners must observe the
	# complete approach -> occupied sequence, with getters and live copy coherent
	# with each event rather than leaking the nested state into the outer event.
	var reentry_berth := BERTH_SCENE.instantiate() as ShipBerth
	reentry_berth.berth_id = &"feedback_reentry_berth"
	stage.add_child(reentry_berth)
	var reentry_feedback := FEEDBACK_SCENE.instantiate() as ShipBerthFeedback
	reentry_berth.add_child(reentry_feedback)
	var reentry_ship := Node3D.new()
	reentry_ship.name = "ReentrantLeaseOwner"
	stage.add_child(reentry_ship)
	await process_frame
	_reentry_berth = reentry_berth
	_reentry_feedback = reentry_feedback
	_reentry_ship = reentry_ship
	_reentry_listener_a.clear()
	_reentry_listener_b.clear()
	_reentry_occupy_results.clear()
	reentry_feedback.state_changed.connect(_on_reentry_listener_a)
	reentry_feedback.state_changed.connect(_on_reentry_listener_b)
	var reentry_token := reentry_berth.try_reserve(reentry_ship, TORRENT_DEFINITION)
	_check(
		not reentry_token.is_empty()
		and _reentry_occupy_results == [true]
		and reentry_berth.get_occupant() == reentry_ship,
		"first synchronous feedback listener can convert the live reservation to occupancy exactly once"
	)
	_check(
		_reentry_observations_are_coherent(_reentry_listener_a)
		and _reentry_observations_are_coherent(_reentry_listener_b),
		"both synchronous listeners observe exact approach then occupied events with coherent getter and label state"
	)
	reentry_feedback.state_changed.disconnect(_on_reentry_listener_a)
	reentry_feedback.state_changed.disconnect(_on_reentry_listener_b)
	_check(reentry_berth.release(reentry_ship, reentry_token), "reentrant lease fixture releases through the returned authoritative token")
	reentry_ship.queue_free()

	# Weak-reference reconciliation must keep polling while presentation animation
	# is both manually clocked and paused. Inspect the emitted transition and live
	# label first: neither a state getter nor manual advancement may cause the fix.
	feedback.set_auto_advance_enabled(false)
	feedback.set_feedback_paused(true)
	_weak_reconcile_states.clear()
	feedback.state_changed.connect(_on_weak_reconcile_state_changed)
	var passive_owner := Node3D.new()
	passive_owner.name = "PassiveWeakLeaseOwner"
	stage.add_child(passive_owner)
	var passive_token := berth.try_reserve(passive_owner, TORRENT_DEFINITION)
	_check(not passive_token.is_empty() and feedback.is_processing(), "paused manual-clock feedback keeps its allocation-free berth reconciliation poll active")
	_weak_reconcile_states.clear()
	passive_owner.queue_free()
	await process_frame
	await process_frame
	await process_frame
	var passive_label := feedback.get_node("FeedbackVisual/LeaseStateLabel") as Label3D
	_check(
		_weak_reconcile_states == [&"released"] and passive_label.text == "BERTH OPEN",
		"paused manual-clock polling reconciles a freed weak owner into released state and live copy without getter or advance"
	)
	feedback.state_changed.disconnect(_on_weak_reconcile_state_changed)
	feedback.set_feedback_paused(false)

	var detached_state_events: Array[StringName] = []
	var detached_state_listener := func(state: StringName) -> void:
		detached_state_events.append(state)
	feedback.state_changed.connect(detached_state_listener)
	berth.remove_child(feedback)
	await process_frame
	var detached_state := feedback.get_state_snapshot()
	feedback.advance_simulation(1.0)
	feedback.seek_simulation(float(detached_state.elapsed) + 3.0)
	_check(
		not feedback.is_inside_tree()
		and feedback.get_state_snapshot() == detached_state
		and detached_state_events.is_empty(),
		"detached berth feedback rejects stale manual clock mutations without publishing state"
	)
	berth.add_child(feedback)
	await process_frame
	_check(feedback.get_feedback_state() == &"released" and bool(feedback.get_audit_report().valid), "child detach and re-add reconnects lifecycle without rebuilding")
	var reentered_elapsed := float(feedback.get_state_snapshot().elapsed)
	feedback.advance_simulation(0.25)
	_check(
		is_equal_approx(float(feedback.get_state_snapshot().elapsed), reentered_elapsed + 0.25),
		"re-added berth feedback accepts a fresh manual advancement"
	)
	feedback.seek_simulation(7.5)
	_check(
		is_equal_approx(float(feedback.get_state_snapshot().elapsed), 7.5),
		"re-added berth feedback accepts a fresh manual seek"
	)
	feedback.state_changed.disconnect(detached_state_listener)

	var stale_owner := Node3D.new()
	stage.add_child(stale_owner)
	var stale_token := berth.try_reserve(stale_owner, TORRENT_DEFINITION)
	_check(not stale_token.is_empty(), "stale-owner fixture obtains a real reservation")
	stale_owner.queue_free()
	await process_frame
	feedback.advance_simulation(0.0)
	_check(feedback.get_feedback_state() == &"released", "polling reconciles weak-owner cleanup even without a berth signal")

	# Every immutable presentation contract must fail red on live drift and return
	# green after the exact value is restored.
	_check(bool(feedback.get_audit_report().valid), "integrity mutation fixture starts from a valid released presentation")
	feedback.visible = false
	_check(not bool(feedback.get_audit_report().valid), "audit rejects direct component visibility drift")
	feedback.visible = true
	_check(bool(feedback.get_audit_report().valid), "restoring component visibility restores a green audit")

	var visual_root := feedback.get_node("FeedbackVisual") as Node3D
	var rogue_label := Label3D.new()
	rogue_label.name = "RogueLeaseLabel"
	visual_root.add_child(rogue_label)
	_check(not bool(feedback.get_audit_report().valid), "audit rejects an unowned second Label3D")
	visual_root.remove_child(rogue_label)
	rogue_label.free()
	_check(bool(feedback.get_audit_report().valid), "removing the rogue label restores exact hierarchy integrity")

	var plate := feedback.get_node("FeedbackVisual/LeaseStatePlate") as MeshInstance3D
	var plate_transform := plate.transform
	plate.position += Vector3(0.25, 0.0, -0.1)
	_check(not bool(feedback.get_audit_report().valid), "audit rejects lease-state plate transform drift")
	plate.transform = plate_transform
	_check(bool(feedback.get_audit_report().valid), "restoring the exact plate transform restores a green audit")

	var plate_box := plate.mesh as BoxMesh
	var plate_box_size := plate_box.size
	plate_box.size += Vector3(0.2, 0.01, 0.15)
	_check(not bool(feedback.get_audit_report().valid), "audit rejects in-place BoxMesh size drift")
	plate_box.size = plate_box_size
	_check(bool(feedback.get_audit_report().valid), "restoring the exact BoxMesh size restores a green audit")

	# Structured negative controls for the sharing seam itself. An equal-recipe
	# duplicate must fail because it reintroduces an eighth retained resource;
	# mutating the shared recipe must fail all four boundary contracts together.
	var shared_boundary_mesh := boundary_port_forward.mesh as BoxMesh
	var duplicate_boundary_mesh := BoxMesh.new()
	duplicate_boundary_mesh.size = shared_boundary_mesh.size
	boundary_port_forward.mesh = duplicate_boundary_mesh
	var duplicate_mesh_report := feedback.get_performance_report()
	_check(
		not bool(feedback.get_audit_report().valid)
		and int(duplicate_mesh_report.mesh_resources) == 8
		and not bool(duplicate_mesh_report.mesh_sharing_exact),
		"audit rejects an equal-size duplicate that reasserts an eighth BoxMesh allocation"
	)
	boundary_port_forward.mesh = shared_boundary_mesh
	_check(
		bool(feedback.get_audit_report().valid)
		and int(feedback.get_performance_report().mesh_resources) == 7,
		"restoring the exact shared boundary identity restores the seven-resource audit"
	)
	var shared_boundary_size := shared_boundary_mesh.size
	shared_boundary_mesh.size += Vector3(0.1, 0.01, 0.02)
	_check(
		not bool(feedback.get_audit_report().valid)
		and (boundary_port_aft.mesh as BoxMesh).size == shared_boundary_mesh.size
		and (boundary_starboard_forward.mesh as BoxMesh).size == shared_boundary_mesh.size
		and (boundary_starboard_aft.mesh as BoxMesh).size == shared_boundary_mesh.size,
		"audit rejects shared recipe drift observed by all four independent boundary copies"
	)
	shared_boundary_mesh.size = shared_boundary_size
	_check(bool(feedback.get_audit_report().valid), "restoring the shared boundary recipe restores a green audit")

	var plate_material := plate.material_override as StandardMaterial3D
	var billboard_mode := plate_material.billboard_mode
	plate_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_check(not bool(feedback.get_audit_report().valid), "audit rejects shared presentation material billboard drift")
	plate_material.billboard_mode = billboard_mode
	_check(bool(feedback.get_audit_report().valid), "restoring material billboard mode restores a green audit")
	var cull_mode := plate_material.cull_mode
	plate_material.cull_mode = BaseMaterial3D.CULL_FRONT
	_check(not bool(feedback.get_audit_report().valid), "audit rejects shared presentation material cull drift")
	plate_material.cull_mode = cull_mode
	_check(bool(feedback.get_audit_report().valid), "restoring material cull mode restores a green audit")

	var state_label := feedback.get_node("FeedbackVisual/LeaseStateLabel") as Label3D
	var label_text := state_label.text
	state_label.text = "MUTATED LEASE COPY"
	_check(not bool(feedback.get_audit_report().valid), "audit rejects live state-label text drift")
	state_label.text = label_text
	_check(bool(feedback.get_audit_report().valid), "restoring state-label text restores a green audit")
	var label_double_sided := state_label.double_sided
	state_label.double_sided = not label_double_sided
	_check(not bool(feedback.get_audit_report().valid), "audit rejects state-label double-sided drift")
	state_label.double_sided = label_double_sided
	_check(bool(feedback.get_audit_report().valid), "restoring label sidedness restores a green audit")
	var label_transform := state_label.transform
	state_label.position += Vector3(0.0, 0.1, 0.2)
	_check(not bool(feedback.get_audit_report().valid), "audit rejects state-label transform drift")
	state_label.transform = label_transform
	_check(bool(feedback.get_audit_report().valid), "restoring the exact label transform restores a green audit")

	# Detachment is recoverable; freeing is tested on a sacrificial component so
	# repeated fail-red audits can prove stale cached references remain safe.
	feedback.remove_child(visual_root)
	var detached_audit_a := feedback.get_audit_report()
	var detached_audit_b := feedback.get_audit_report()
	_check(
		not bool(detached_audit_a.valid)
		and not bool(detached_audit_b.valid)
		and detached_audit_a.errors == detached_audit_b.errors,
		"detached FeedbackVisual fails red consistently across repeated audits"
	)
	feedback.add_child(visual_root)
	await process_frame
	_check(bool(feedback.get_audit_report().valid), "re-attaching the same FeedbackVisual restores the immutable hierarchy")

	var freed_berth := BERTH_SCENE.instantiate() as ShipBerth
	freed_berth.berth_id = &"feedback_freed_visual_berth"
	stage.add_child(freed_berth)
	var freed_feedback := FEEDBACK_SCENE.instantiate() as ShipBerthFeedback
	freed_berth.add_child(freed_feedback)
	await process_frame
	var doomed_visual := freed_feedback.get_node("FeedbackVisual") as Node3D
	doomed_visual.queue_free()
	await process_frame
	await process_frame
	var freed_audit_a := freed_feedback.get_audit_report()
	var freed_audit_b := freed_feedback.get_audit_report()
	_check(
		not bool(freed_audit_a.valid)
		and not bool(freed_audit_b.valid)
		and freed_audit_a.errors == freed_audit_b.errors,
		"freed FeedbackVisual fails red deterministically without recurring audit errors"
	)

	stage.queue_free()
	await process_frame
	await process_frame
	_finish()


## Drives the live component through its three real lease states and freezes both
## readability channels from what it actually renders, not from source constants.
func _test_state_channels(berth: ShipBerth, feedback: ShipBerthFeedback, ship: Node3D) -> void:
	var plate := feedback.get_node("FeedbackVisual/LeaseStatePlate") as MeshInstance3D
	var label := feedback.get_node("FeedbackVisual/LeaseStateLabel") as Label3D
	var emissions: Dictionary = {}
	var albedos: Dictionary = {}
	var label_tints: Dictionary = {}
	var glyph_ids: Dictionary = {}
	var glyph_meshes: Dictionary = {}
	var glyph_footprints: Dictionary = {}
	var token: StringName = &""

	for state: StringName in CUE_STATES:
		if state == &"approach":
			token = berth.try_reserve(ship, TORRENT_DEFINITION)
		elif state == &"occupied":
			berth.occupy(ship, token)
		await process_frame
		_check(
			feedback.get_feedback_state() == state,
			"channel sampling reads the real %s lease from the authoritative berth" % state
		)
		var material := plate.material_override as StandardMaterial3D
		emissions[state] = material.emission.to_html(false)
		albedos[state] = material.albedo_color.to_html(false)
		var tint := label.modulate
		tint.a = 1.0
		label_tints[state] = tint.to_html(false)
		var snapshot := feedback.get_state_snapshot()
		glyph_ids[state] = StringName(snapshot.get("cue_glyph", &""))
		glyph_meshes[state] = snapshot.get("cue_glyph_mesh_names", PackedStringArray()) as PackedStringArray
		glyph_footprints[state] = float(snapshot.get("cue_glyph_footprint", 0.0))
	berth.release(ship, token)
	await process_frame
	_check(feedback.get_feedback_state() == &"released", "channel sampling returns the fixture berth to open")

	# ------------------------------------------------------------- colour ----
	for mode: String in ColourMetrics.VISION_MODELS:
		var emission_minimum := ColourMetrics.minimum_separation(emissions, mode)
		var albedo_minimum := ColourMetrics.minimum_separation(albedos, mode)
		var label_minimum := ColourMetrics.minimum_separation(label_tints, mode)
		print(
			"BERTH_CUE_COLOUR_EVIDENCE: under %s emission_min_ciede2000=%.2f albedo_min_ciede2000=%.2f label_min_ciede2000=%.2f"
				% [mode, emission_minimum, albedo_minimum, label_minimum]
		)
		_check(
			emission_minimum >= CUE_EMISSION_FLOOR,
			"emissive cue separation under %s holds its %.1f floor (%.2f)"
				% [mode, CUE_EMISSION_FLOOR, emission_minimum]
		)
		_check(
			albedo_minimum >= CUE_ALBEDO_FLOOR,
			"cue albedo separation under %s holds its %.1f floor (%.2f)"
				% [mode, CUE_ALBEDO_FLOOR, albedo_minimum]
		)
		_check(
			label_minimum >= CUE_LABEL_FLOOR,
			"state-label tint separation under %s holds its %.1f floor (%.2f)"
				% [mode, CUE_LABEL_FLOOR, label_minimum]
		)
		# Structured negative control: the palette this replaced must still fail.
		var defect_minimum := ColourMetrics.minimum_separation(AUDITED_DEFECT_EMISSION, mode)
		_check(
			defect_minimum < CUE_EMISSION_FLOOR,
			"the audited cyan/amber/green cue still fails the %s gate it was replaced for (%.2f)"
				% [mode, defect_minimum]
		)
	_check(
		ColourMetrics.minimum_separation(AUDITED_DEFECT_EMISSION, "tritanopia") < 3.0,
		"the audited defect is recorded at its measured severity: below the practical JND under tritanopia"
	)
	# Lightness is the one channel every dichromacy model preserves, so the triad
	# must be a ladder in L* and not only a hue wheel.
	var lightnesses := PackedFloat32Array()
	for state: StringName in CUE_STATES:
		lightnesses.append(ColourMetrics.lightness(str(emissions[state])))
	_check(
		lightnesses[0] - lightnesses[1] >= 12.0 and lightnesses[1] - lightnesses[2] >= 12.0,
		"the cue triad descends a lightness ladder open > approach > secured (L* %.1f / %.1f / %.1f)"
			% [lightnesses[0], lightnesses[1], lightnesses[2]]
	)

	# -------------------------------------------------------------- shape ----
	var seen_glyph_ids := PackedStringArray()
	var seen_glyph_meshes := PackedStringArray()
	var seen_footprints := PackedFloat32Array()
	for state: StringName in CUE_STATES:
		var glyph_id := StringName(glyph_ids[state])
		var meshes := glyph_meshes[state] as PackedStringArray
		var footprint := float(glyph_footprints[state])
		_check(
			glyph_id == StringName(EXPECTED_GLYPH_IDS[state]),
			"%s publishes its exact non-colour glyph identity %s" % [state, glyph_id]
		)
		_check(not meshes.is_empty(), "%s renders at least one glyph mesh" % state)
		_check(footprint > 0.0, "%s glyph covers real deck area (%.3f m^2)" % [state, footprint])
		if seen_glyph_ids.has(String(glyph_id)):
			_check(false, "%s reuses a glyph identity another state already owns" % state)
		seen_glyph_ids.append(String(glyph_id))
		for mesh_name in meshes:
			_check(
				not seen_glyph_meshes.has(mesh_name),
				"glyph mesh %s belongs to exactly one state" % mesh_name
			)
			seen_glyph_meshes.append(mesh_name)
		for other in seen_footprints:
			_check(
				absf(other - footprint) >= 0.15,
				"%s glyph ink coverage is separable from every other state (%.3f vs %.3f m^2)"
					% [state, footprint, other]
			)
		seen_footprints.append(footprint)
	_check(
		seen_glyph_meshes.size() == 5,
		"the three glyphs are drawn by five mutually exclusive meshes (%d)" % seen_glyph_meshes.size()
	)
	# The shape channel must be as fail-red as every other frozen contract: a
	# glyph shown outside its own state is drift, not decoration.
	_check(bool(feedback.get_audit_report().valid), "shape-channel mutation fixture starts green in the open state")
	var secured_glyph := feedback.get_node("FeedbackVisual/GlyphSecuredBar") as MeshInstance3D
	secured_glyph.visible = true
	_check(
		not bool(feedback.get_audit_report().valid),
		"audit rejects the secured glyph rendered on an open berth"
	)
	secured_glyph.visible = false
	_check(bool(feedback.get_audit_report().valid), "hiding the wrong-state glyph restores a green audit")
	var gate_glyph := feedback.get_node("FeedbackVisual/GlyphGatePort") as MeshInstance3D
	gate_glyph.visible = false
	_check(
		not bool(feedback.get_audit_report().valid),
		"audit rejects an open berth that has stopped drawing its own gate glyph"
	)
	gate_glyph.visible = true
	_check(bool(feedback.get_audit_report().valid), "restoring the open-state glyph restores a green audit")


func _on_reentry_listener_a(state: StringName) -> void:
	_record_reentry_observation(_reentry_listener_a, state)
	if state != &"approach" or not is_instance_valid(_reentry_berth) or not is_instance_valid(_reentry_ship):
		return
	var live_token := _reentry_berth.get_reservation_token(_reentry_ship)
	_reentry_occupy_results.append(_reentry_berth.occupy(_reentry_ship, live_token))


func _on_reentry_listener_b(state: StringName) -> void:
	_record_reentry_observation(_reentry_listener_b, state)


func _record_reentry_observation(target: Array[Dictionary], state: StringName) -> void:
	var label := _reentry_feedback.get_node("FeedbackVisual/LeaseStateLabel") as Label3D
	target.append({
		"event": state,
		"getter": _reentry_feedback.get_feedback_state(),
		"label": label.text,
	})


func _reentry_observations_are_coherent(observations: Array[Dictionary]) -> bool:
	if observations.size() != 2:
		return false
	var expected_states: Array[StringName] = [&"approach", &"occupied"]
	var expected_labels := ["APPROACH VECTOR", "BERTH SECURED"]
	for index in expected_states.size():
		var observation := observations[index]
		if observation.get("event", &"") != expected_states[index] \
				or observation.get("getter", &"") != expected_states[index] \
				or str(observation.get("label", "")) != expected_labels[index]:
			return false
	return true


func _on_weak_reconcile_state_changed(state: StringName) -> void:
	_weak_reconcile_states.append(state)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if _failures.is_empty():
		print("SHIP_BERTH_FEEDBACK_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("SHIP_BERTH_FEEDBACK_TEST_FAILED: %s" % ", ".join(_failures))
		quit(1)
