extends SceneTree

## Production ultrawide / minimum-aspect HUD layout proof.
##
## WHY THIS SUITE EXISTS. `ROADMAP.md` Phase 9 asks for production-grade settings
## coverage with ultrawide testing, and Phase 10 §3 asks for a review of the
## complete game at 21:9, 32:9 and the 4:3 minimum under the reduced-motion and
## large-text/caption accessibility presets. The existing layout suites each
## prove one slice: `hud_panel_layout_test.gd` sweeps UI scale at 16:9-ish
## viewports, `hud_ultrawide_safe_area_test.gd` proves the caption composition in
## a detached `SubViewport`, and `runtime_status_*_layout_test.gd` prove one card
## arithmetically. None of them boots production `Main`, none of them resizes the
## real `Window`, and none of them walks *every* visible `Control` of a state.
##
## This suite does all three. It boots `res://scenes/main.tscn`, resizes the live
## window (and its content-scale size, see `_apply_resolution`) to each supported
## display, drives the shipping HUD through its real states, and then measures
## every visible drawing `Control` in the tree:
##
##   * fully inside the viewport rect, and inside the authored safe rect from
##     `UltrawideSafeAreaContract` (full-rect-anchored backdrops and anything
##     inside a clipping container are exempt -- they are authored to span or to
##     be scrolled);
##   * no overlap between the gameplay cards that are simultaneously visible;
##   * effective font pixel size at or above the readability floor;
##   * centre-anchored cards grow in both directions and keep a *resolution
##     invariant* centre bias, so an authored centred card cannot drift with the
##     aspect ratio;
##   * every property above still holds under the reduced-motion and
##     large-text/caption accessibility presets.
##
## READABILITY FLOOR. The project defines no `minimum_font`/`readability`
## constant (grep: only 3D signage sizes and `AccessibilityVisualPreset`'s
## contrast ratios). The floor used here is therefore derived from the two
## numbers the project *does* author: the smallest HUD body font actually used by
## `GameHUD` (9 px, the muted status/footnote rows) and the smallest UI scale the
## accessibility contract admits (`AccessibilityVisualPreset.MIN_SCALE` 0.75).
## Their product is the smallest glyph the shipping configuration can legally
## produce, so any measurement below it is a new defect rather than an authored
## choice.
##
## CAMERA. The hero chase/cockpit rigs are measured here too: the roadmap item
## asks whether horizontal FOV explodes at 32:9. It did. Godot's
## `Camera3D.KEEP_HEIGHT` is the project's vertical-FOV policy -- `HeroShip`
## relies on it explicitly in `_chase_camera_boundary_samples` -- so the authored
## `camera_fov` is the vertical angle and the horizontal angle widened without
## limit: 104.5 degrees at 16:9, 120.1 at 21:9, 137.7 at 32:9.
##
## `UltrawideFovPolicy` now caps that, and the player can opt out with
## `limit_ultrawide_fov` (default ON). The measurement here walks every supported
## resolution twice -- cap on and cap off -- and prints the whole table, because
## the contract has two halves that are only convincing together: at 21:9 and
## narrower the authored angle must survive *exactly*, and above 21:9 the
## horizontal angle must sit on the ceiling that same authored angle reaches at
## 21:9. See `docs/ULTRAWIDE_FIELD_OF_VIEW_POLICY.md`.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const HudType := preload("res://scripts/ui/hud.gd")
const Contract := preload("res://scripts/ui/ultrawide_safe_area_contract.gd")
const RestOverlayType := preload("res://scripts/ui/ship_rest_overlay.gd")
const AccessibilityPreset := preload("res://scripts/ui/accessibility_visual_preset.gd")
const RuntimeSettingsType := preload("res://scripts/settings/runtime_settings.gd")

## The shipping `camera_fov` default, and the angle the whole FOV table below is
## measured at.
const AUTHORED_CAMERA_FOV := 72.0

## The 4:3 minimum, the two shipping 16:9 sizes, and the two ultrawide panels the
## roadmap names. 1024x768 is below the project's 1600x900 stretch viewport in
## both axes, so it is the worst case for every vertical reservation.
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1024, 768),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3440, 1440),
	Vector2i(5120, 1440),
]

## Smallest authored `GameHUD` body font size, in logical px.
const SMALLEST_AUTHORED_FONT_SIZE := 9.0

## Smallest glyph the shipping scale contract can produce, in device px.
const READABILITY_FLOOR_PX := SMALLEST_AUTHORED_FONT_SIZE * AccessibilityPreset.MIN_SCALE

## Sub-pixel slack for rect containment. Layout arithmetic is float, and a card
## that ends exactly on the safe edge is authored, not broken.
const EDGE_TOLERANCE := 0.75

## Two cards closer than this still pass but are reported, so an edit that eats
## the margin is visible before it becomes a collision.
const CLEARANCE_WATCH := 6.0

## Cards whose authored centre bias must not move with the aspect ratio.
const CENTRE_BIAS_TOLERANCE := 0.5

## Accessibility presets. The project exposes reduced motion, reduced flash,
## captions and UI scale as independent settings rather than named bundles, so
## these are the combinations `RuntimeSettings.get_accessibility_descriptor()`
## can actually hand `GameHUD.set_accessibility`.
const PRESETS := [
	{
		"id": &"authored",
		"descriptor": {
			"ui_scale": 1.0,
			"reduced_motion": false,
			"reduced_flash": false,
			"captions_enabled": false,
		},
	},
	{
		"id": &"reduced_motion",
		"descriptor": {
			"ui_scale": 1.0,
			"reduced_motion": true,
			"reduced_flash": true,
			"captions_enabled": true,
		},
	},
	{
		"id": &"large_text_captions",
		"descriptor": {
			"ui_scale": AccessibilityPreset.MAX_SCALE,
			"reduced_motion": true,
			"reduced_flash": true,
			"captions_enabled": true,
		},
	},
	{
		"id": &"high_contrast_large_reticle",
		"descriptor": {
			"ui_scale": 1.0,
			"reduced_motion": false,
			"reduced_flash": false,
			"captions_enabled": true,
			"high_contrast_hud": true,
			"reticle_style": &"large",
		},
	},
]

## Every HUD state the roadmap item names, in the order the suite drives them.
const STATES: Array[StringName] = [
	&"approach_prompt",
	&"boarding_card",
	&"tutorial_card",
	&"activity_briefing",
	&"objective",
	&"weapon_readiness",
	&"component_damage",
	&"captions",
	&"fleet_registry",
	&"ship_rest_overlay",
	&"pause_menu",
	&"settings_menu",
	&"activity_board",
]

## Gameplay cards that share the screen and must stay pairwise disjoint. Pause
## pages are modal and mutually exclusive, so they are excluded by construction.
const SIMULTANEOUS_CARDS := [
	"_brand_block",
	"_objective_panel",
	"_help_panel",
	"_telemetry_panel",
	"_minimap",
	"_toast_panel",
	"_enemy_panel",
	"_interaction_panel",
	"_runtime_status_panel",
	"_semantic_transcript_toggle",
	"_semantic_transcript_panel",
]

## Card pairs that share the screen but are *not* an authored simultaneous
## composition. The expanded semantic caption log is a top-centre inspection
## surface the player toggles open, and the toast occupies the same top-centre
## band: they overlap by the same amount at every resolution and aspect ratio,
## including the shipping 16:9, so this is a composition decision rather than an
## ultrawide layout defect. `hud_ultrawide_safe_area_test.gd` already draws the
## same line -- its expanded-log composition deliberately omits the toast.
const NON_SIMULTANEOUS_PAIRS := [
	["ToastPanel", "SemanticCaptionTranscriptPanel"],
]

## Longest strings the shipping callers in `scripts/game/game_flow.gd` ever set.
## Measuring placeholder text would prove nothing: these cards size to content.
const LONGEST_OBJECTIVE := "Free flight — explore, fight, or return to a compatible registered berth"
const LONGEST_INTERACTION := "Clear the berth before requesting a return approach"

var _failures: Array[String] = []
var _assertions := 0
var _game: GameFlow
var _hud: GameHUD
var _rest_overlay: CanvasLayer
var _centre_bias: Dictionary = {}
var _worst_clearance := INF
var _worst_clearance_label := ""
var _worst_font := INF
var _worst_font_label := ""
var _restore_size := Vector2i.ZERO
var _restore_content_size := Vector2i.ZERO
var _restore_aspect: Window.ContentScaleAspect = Window.CONTENT_SCALE_ASPECT_KEEP
## Tutorial presenters reject a snapshot older than the one they retain, so each
## publication uses a fresh generation instead of replaying a fixed one.
var _tutorial_generation := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_restore_size = root.size
	_restore_content_size = root.content_scale_size
	_restore_aspect = root.content_scale_aspect

	_game = MAIN_SCENE.instantiate() as GameFlow
	_check(_game != null, "production main scene instantiates")
	if _game == null:
		_finish()
		return
	root.add_child(_game)
	await process_frame
	await physics_frame
	_game.start_shift()
	await process_frame
	_hud = _game.hud as GameHUD
	_check(_hud != null, "production Main exposes the shipping GameHUD")
	if _hud == null:
		await _teardown()
		_finish()
		return
	# The shift intro is a full-screen splash; the layout under review is the
	# gameplay surface behind it.
	_hud.set("_started", true)
	(_hud.get("_intro") as Control).visible = false
	(_hud.get("_hud") as Control).visible = true
	# GameFlow already installs the production caption sink on a live Main, so a
	# second binding is refused by design. Bind only when the seam is free.
	_hud.bind_caption_event_submitter(Callable(self, &"_accept_caption_request"))

	_report_production_stretch_policy()
	await _check_camera_field_of_view_policy()

	for resolution in RESOLUTIONS:
		await _apply_resolution(resolution)
		for preset: Dictionary in PRESETS:
			var descriptor := (preset["descriptor"] as Dictionary).duplicate()
			# Presets that do not name the two HUD presentation settings run with
			# them off, so the frozen authored layout is measured as authored.
			if not descriptor.has("high_contrast_hud"):
				descriptor["high_contrast_hud"] = false
			if not descriptor.has("reticle_style"):
				descriptor["reticle_style"] = &"standard"
			_hud.set_accessibility(descriptor)
			await process_frame
			_check(
				_hud.is_high_contrast_hud() == bool(descriptor["high_contrast_hud"])
				and _hud.get_reticle_style() == StringName(descriptor["reticle_style"]),
				"%s applies its contrast and reticle presentation before measurement" % preset["id"]
			)
			for state in STATES:
				await _exercise_state(resolution, StringName(preset["id"]), state)

	print(
		"MEASURED: tightest card clearance %.1f px (%s); smallest glyph %.2f px (%s)"
		% [_worst_clearance, _worst_clearance_label, _worst_font, _worst_font_label]
	)
	await _teardown()
	_finish()


## The live window is the authority for this suite, but the shipping project
## pins `display/window/stretch/aspect` to `keep` with a 1600x900 content size,
## which freezes the viewport at 1600x900 whatever the window does. Resizing the
## window alone would therefore measure 16:9 five times over. Expanding the
## content size to the requested display is exactly the geometry a native
## ultrawide/4:3 client has to lay out, so that is what is set here.
func _apply_resolution(resolution: Vector2i) -> void:
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = resolution
	root.size = resolution
	await process_frame
	await process_frame
	_check(
		Vector2i(root.get_visible_rect().size) == resolution,
		"the live window delivers a %dx%d viewport to the production HUD"
		% [resolution.x, resolution.y]
	)


func _exercise_state(resolution: Vector2i, preset_id: StringName, state: StringName) -> void:
	await _enter_state(state)
	await process_frame
	await process_frame
	var report := _measure(resolution, preset_id, state)
	print("ULTRAWIDE_LAYOUT ", JSON.stringify(report))
	var label := "%dx%d %s/%s" % [resolution.x, resolution.y, preset_id, state]
	_check(
		(report["outside_viewport"] as Array).is_empty(),
		"%s keeps every visible control inside the viewport%s"
		% [label, _detail(report["outside_viewport"] as Array)]
	)
	_check(
		(report["outside_safe_area"] as Array).is_empty(),
		"%s keeps every visible control inside the authored safe margin%s"
		% [label, _detail(report["outside_safe_area"] as Array)]
	)
	_check(
		(report["overlaps"] as Array).is_empty(),
		"%s keeps the simultaneously visible cards disjoint%s"
		% [label, _detail(report["overlaps"] as Array)]
	)
	_check(
		float(report["min_font_px"]) >= READABILITY_FLOOR_PX,
		"%s keeps every glyph at or above the %.2f px readability floor (%.2f px on %s)"
		% [label, READABILITY_FLOOR_PX, report["min_font_px"], report["min_font_control"]]
	)
	_check(
		(report["asymmetric_centres"] as Array).is_empty(),
		"%s keeps authored centred cards symmetric and aspect invariant%s"
		% [label, _detail(report["asymmetric_centres"] as Array)]
	)
	await _leave_state(state)


func _measure(resolution: Vector2i, preset_id: StringName, state: StringName) -> Dictionary:
	var viewport_size := root.get_visible_rect().size
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	var effective := float(_hud.get("_layout_effective_ui_scale"))
	var safe := Contract.safe_rect(viewport_size, effective)
	# The modal pause layer resolves its own scale against the larger pause
	# contract, and the contract's margins scale with whichever factor a control
	# is actually laid out under.
	var pause_effective := float(_hud.get("_pause_effective_ui_scale"))
	var pause_safe := Contract.safe_rect(viewport_size, pause_effective)
	var pause_layer := _hud.get("_pause_panels") as Control
	var entries := _collect_controls()
	var outside_viewport: Array[String] = []
	var outside_safe: Array[String] = []
	var asymmetric: Array[String] = []
	var min_font := INF
	var min_font_label := "none"
	var measured := 0
	for entry: Dictionary in entries:
		var control := entry["control"] as Control
		var rect := control.get_global_rect()
		if _is_measured_control(control) and rect.size.x > 0.5 and rect.size.y > 0.5:
			measured += 1
			if not bool(entry["clipped"]):
				var applicable := safe
				if is_instance_valid(pause_layer) and pause_layer.is_ancestor_of(control):
					applicable = pause_safe
				if not viewport_rect.grow(EDGE_TOLERANCE).encloses(rect):
					outside_viewport.append("%s %s" % [_path(control), rect])
				elif not _is_full_rect(control) \
						and not applicable.grow(EDGE_TOLERANCE).encloses(rect):
					outside_safe.append("%s %s" % [_path(control), rect])
		var font_px := _effective_font_px(control)
		if font_px > 0.0 and font_px < min_font:
			min_font = font_px
			min_font_label = _path(control)
		var centre_defect := _centre_defect(control, resolution)
		if not centre_defect.is_empty():
			asymmetric.append(centre_defect)
	if min_font < _worst_font:
		_worst_font = min_font
		_worst_font_label = "%dx%d %s/%s %s" % [
			resolution.x, resolution.y, preset_id, state, min_font_label,
		]
	var overlap_report := _measure_card_overlaps(resolution, preset_id, state)
	return {
		"resolution": "%dx%d" % [resolution.x, resolution.y],
		"aspect_bucket": str(Contract.classify_viewport(viewport_size)),
		"preset": str(preset_id),
		"state": str(state),
		"effective_ui_scale": snappedf(effective, 0.0001),
		"pause_effective_ui_scale": snappedf(
			float(_hud.get("_pause_effective_ui_scale")), 0.0001
		),
		"logical_size": [
			snappedf(viewport_size.x / effective, 0.01),
			snappedf(viewport_size.y / effective, 0.01),
		],
		"safe_rect": [
			snappedf(safe.position.x, 0.01), snappedf(safe.position.y, 0.01),
			snappedf(safe.size.x, 0.01), snappedf(safe.size.y, 0.01),
		],
		"pause_safe_rect": [
			snappedf(pause_safe.position.x, 0.01), snappedf(pause_safe.position.y, 0.01),
			snappedf(pause_safe.size.x, 0.01), snappedf(pause_safe.size.y, 0.01),
		],
		"visible_controls": entries.size(),
		"measured_controls": measured,
		"outside_viewport": outside_viewport,
		"outside_safe_area": outside_safe,
		"overlaps": overlap_report["overlaps"],
		"tightest_clearance": overlap_report["tightest"],
		"min_font_px": snappedf(min_font if is_finite(min_font) else 0.0, 0.01),
		"min_font_control": min_font_label,
		"asymmetric_centres": asymmetric,
	}


func _measure_card_overlaps(
	resolution: Vector2i, preset_id: StringName, state: StringName
) -> Dictionary:
	var cards: Array[Dictionary] = []
	for member: String in SIMULTANEOUS_CARDS:
		var control := _hud.get(member) as Control
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		if rect.size.x <= 0.5 or rect.size.y <= 0.5:
			continue
		cards.append({"name": control.name, "rect": rect})
	var caption_rect := _caption_panel_rect()
	if caption_rect.size.x > 0.5 and caption_rect.size.y > 0.5:
		cards.append({"name": "CaptionPanel", "rect": caption_rect})
	var overlaps: Array[String] = []
	var tightest := INF
	var tightest_pair := ""
	for first_index in cards.size():
		for second_index in range(first_index + 1, cards.size()):
			var first := cards[first_index]
			var second := cards[second_index]
			var first_rect := first["rect"] as Rect2
			var second_rect := second["rect"] as Rect2
			if _is_excluded_pair(str(first["name"]), str(second["name"])):
				continue
			if first_rect.intersects(second_rect):
				overlaps.append("%s %s x %s %s" % [
					first["name"], first_rect, second["name"], second_rect,
				])
				continue
			var clearance := _clearance(first_rect, second_rect)
			if clearance < tightest:
				tightest = clearance
				tightest_pair = "%s/%s" % [first["name"], second["name"]]
	if is_finite(tightest) and tightest < _worst_clearance:
		_worst_clearance = tightest
		_worst_clearance_label = "%s at %dx%d %s/%s" % [
			tightest_pair, resolution.x, resolution.y, preset_id, state,
		]
	return {
		"overlaps": overlaps,
		"tightest": snappedf(tightest if is_finite(tightest) else -1.0, 0.01),
		"tightest_pair": tightest_pair,
		"watch": is_finite(tightest) and tightest < CLEARANCE_WATCH,
	}


func _is_excluded_pair(first: String, second: String) -> bool:
	for pair: Array in NON_SIMULTANEOUS_PAIRS:
		if (first == pair[0] and second == pair[1]) \
				or (first == pair[1] and second == pair[0]):
			return true
	return false


## Separation between two disjoint rectangles along the axis that separates them.
func _clearance(first: Rect2, second: Rect2) -> float:
	var horizontal := maxf(first.position.x - second.end.x, second.position.x - first.end.x)
	var vertical := maxf(first.position.y - second.end.y, second.position.y - first.end.y)
	return maxf(horizontal, vertical)


## A card authored centred (left and right anchors both at the midpoint) must
## grow in both directions, and its authored bias off the midpoint must not move
## with the aspect ratio. A bias that changes between 16:9 and 32:9 is a card
## drifting towards an ultrawide edge.
func _centre_defect(control: Control, resolution: Vector2i) -> String:
	if not is_equal_approx(control.anchor_left, 0.5) \
			or not is_equal_approx(control.anchor_right, 0.5):
		return ""
	if control.grow_horizontal != Control.GROW_DIRECTION_BOTH:
		return "%s centred anchors with grow_horizontal=%d" % [
			_path(control), control.grow_horizontal,
		]
	var bias := control.offset_left + control.offset_right
	var key := _path(control)
	if not _centre_bias.has(key):
		_centre_bias[key] = {"bias": bias, "resolution": resolution}
		return ""
	var recorded := _centre_bias[key] as Dictionary
	if absf(float(recorded["bias"]) - bias) <= CENTRE_BIAS_TOLERANCE:
		return ""
	return "%s centre bias %.2f drifted from %.2f first seen at %s" % [
		key, bias, recorded["bias"], recorded["resolution"],
	]


func _caption_panel_rect() -> Rect2:
	var presenter := _hud.get("_caption_presenter") as Control
	if not is_instance_valid(presenter) or not presenter.is_visible_in_tree():
		return Rect2()
	if not presenter.has_method(&"get_layout_report"):
		return Rect2()
	var report := presenter.call(&"get_layout_report") as Dictionary
	if not bool(report.get("visible", false)):
		return Rect2()
	return report.get("panel_rect", Rect2()) as Rect2


## Every visible Control under the HUD layer and any live overlay layer, with the
## flag that says whether a clipping ancestor is allowed to crop it.
func _collect_controls() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	_collect_from(_hud, entries, false)
	if is_instance_valid(_rest_overlay) and _rest_overlay.visible:
		_collect_from(_rest_overlay, entries, false)
	return entries


func _collect_from(node: Node, entries: Array[Dictionary], clipped: bool) -> void:
	for child in node.get_children():
		var next_clipped := clipped
		var control := child as Control
		if control != null:
			if not control.visible:
				continue
			entries.append({"control": control, "clipped": clipped})
			if control.clip_contents or control is ScrollContainer:
				next_clipped = true
		_collect_from(child, entries, next_clipped)


## Controls that actually put ink on screen. Pure layout nodes (VBox/HBox/Margin
## and bare `Control` hosts) are skipped: a container that overflows is caught by
## its drawing children, while the scaled panel layers are viewport-sized hosts
## by construction and would only report themselves.
func _is_measured_control(control: Control) -> bool:
	return (
		control is Label
		or control is RichTextLabel
		or control is BaseButton
		or control is Range
		or control is PanelContainer
		or control is Panel
		or control is TextureRect
		or control is ColorRect
	)


## Backdrops, dimmers and the damage flash are authored to span the display, so
## the readable safe band does not apply to them; the viewport bound still does.
func _is_full_rect(control: Control) -> bool:
	return (
		is_equal_approx(control.anchor_left, 0.0)
		and is_equal_approx(control.anchor_top, 0.0)
		and is_equal_approx(control.anchor_right, 1.0)
		and is_equal_approx(control.anchor_bottom, 1.0)
	)


func _effective_font_px(control: Control) -> float:
	var size := 0
	if control is Label or control is RichTextLabel or control is BaseButton \
			or control is LineEdit:
		size = control.get_theme_font_size(&"font_size")
	if size <= 0:
		return 0.0
	if str(control.get("text")).strip_edges().is_empty():
		return 0.0
	return float(size) * absf(control.get_global_transform().get_scale().y)


func _path(control: Control) -> String:
	var names: Array[String] = [str(control.name)]
	var parent := control.get_parent()
	var depth := 0
	while parent != null and depth < 4 and parent != _hud and parent != _rest_overlay:
		names.push_front(str(parent.name))
		parent = parent.get_parent()
		depth += 1
	return "/".join(names)


# --- State drivers -----------------------------------------------------------


func _enter_state(state: StringName) -> void:
	match state:
		&"approach_prompt":
			_hud.set_mode("on_foot")
			_hud.set_objective(LONGEST_OBJECTIVE, "CURRENT OBJECTIVE")
			_hud.set_interaction(LONGEST_INTERACTION, true)
		&"boarding_card":
			_hud.set_mode("on_foot")
			_hud.set_interaction(LONGEST_INTERACTION, true)
			_check(
				_hud.set_runtime_status_card(&"boarding_confirmation", {
					"title": "[!] BOARDING STATUS",
					"message": (
						"Torrent-class Interceptor is reserved for the guided test."
						+ "\nClear the berth before requesting a return approach."
					),
					"state": "[!] RESERVED",
					"presentation_only": true,
				}, true),
				"the production boarding confirmation card publishes"
			)
		&"tutorial_card":
			_hud.set_mode("piloting")
			_tutorial_generation += 1
			_check(
				_hud.apply_first_sortie_tutorial_snapshot({
					"step_id": &"launch",
					"generation": _tutorial_generation,
					"revision": 1,
				}),
				"the production first-sortie tutorial card publishes"
			)
		&"activity_briefing":
			_hud.set_mode("piloting")
			_tutorial_generation += 1
			_check(
				_hud.apply_activity_tutorial_snapshot({
					"activity_id": &"cinder_reach_checkpoint_route",
					"generation": _tutorial_generation,
					"revision": 1,
				}),
				"the production activity briefing card publishes"
			)
		&"objective":
			_hud.set_mode("piloting")
			_hud.set_ship_identity("Cinder long-range bomber", "Long-range bomber")
			_hud.set_objective(LONGEST_OBJECTIVE, "SANDBOX SORTIE")
			_hud.set_target_count(2, 3)
			_hud.set_activity_objective("Cinder Reach beacon route", {
				"activity_id": &"cinder_reach_checkpoint_route",
				"activity_kind": &"patrol",
				"state_id": &"active",
				"phase_id": &"active",
				"generation": 8,
				"session_generation": 8,
				"activity_generation": 8,
				"next_checkpoint_index": 4,
				"checkpoint_count": 5,
				"completed_checkpoint_count": 3,
				"current_time_seconds": 58.4,
			})
		&"weapon_readiness":
			_hud.set_mode("piloting")
			_hud.set_enemy_status("Mudds range defence interceptor", 22.0, 100.0, true)
			_hud.set_target_lock_state(&"acquired", "Mudds range defence interceptor")
			_hud.update_ship_telemetry({
				"weapon_heat": 0.92,
				"weapon_overheated": true,
				"weapon_ready": false,
				"hull": 0.46,
				"shield": 0.12,
				"throttle": 0.8,
				"speed": 128.0,
			})
		&"component_damage":
			_hud.set_mode("piloting")
			_hud.update_component_degradation({
				"engine_power": 0.42,
				"weapon_power": 0.0,
				"targeting_power": 0.66,
				"affected_component": "starboard_wing",
				"repair_history": [
					"engine bay restored", "core systems restored",
					"port wing restored", "forward hull restored",
				],
			})
		&"captions":
			_hud.set_mode("piloting")
			_hud.set_captions_enabled(true)
			var cues: Array[StringName] = [
				&"combat_alert", &"target_destroyed", &"hull_impact_heavy",
				&"engine_damage_alarm", &"target_lock_acquired", &"weapon_not_ready",
				&"boost_engaged", &"surface_touchdown",
			]
			for index in cues.size():
				_hud.present_semantic_audio_cue(
					cues[index], StringName("ultrawide_source_%d" % index), 0.8,
					Vector3.ZERO, {"tick": index + 1, "direction": "rear-left"}
				)
			if not bool((_hud.get("_semantic_transcript_panel") as Control).visible):
				_hud.toggle_semantic_caption_transcript()
		&"fleet_registry":
			_hud.set_mode("on_foot")
			_hud.toast(
				"Fleet registry refreshed",
				"4 available // 2 occupied // 1 destroyed // 1 regenerating",
				600.0
			)
		&"ship_rest_overlay":
			if not is_instance_valid(_rest_overlay):
				_rest_overlay = RestOverlayType.new() as CanvasLayer
				_rest_overlay.name = "UltrawideRestOverlay"
				_game.add_child(_rest_overlay)
			_rest_overlay.call(&"begin_rest", "Cinder long-range bomber", "E")
		&"pause_menu":
			_hud.set_paused(true)
		&"settings_menu":
			_hud.set_paused(true)
			_hud.call(&"_show_settings_page")
		&"activity_board":
			_check(_hud.open_activity_board(), "the production activity board opens")


func _leave_state(state: StringName) -> void:
	match state:
		&"approach_prompt":
			_hud.set_interaction("", false)
		&"boarding_card":
			_hud.set_interaction("", false)
			_hud.clear_runtime_status_card(&"boarding_confirmation")
		&"tutorial_card":
			_hud.clear_first_sortie_tutorial(&"detached")
		&"activity_briefing":
			_hud.clear_activity_tutorial(&"detached")
		&"objective":
			_hud.clear_activity_objective()
			_hud.set_target_count(0, 0)
		&"weapon_readiness":
			_hud.set_enemy_status("", 0.0, 100.0, false)
			_hud.set_target_lock_state(&"searching")
		&"component_damage":
			_hud.clear_component_degradation()
		&"captions":
			if bool((_hud.get("_semantic_transcript_panel") as Control).visible):
				_hud.toggle_semantic_caption_transcript()
			_hud.clear_semantic_caption_transcript()
			_hud.set_captions_enabled(false)
		&"fleet_registry":
			# The toast owns its own dismissal tween; hide the retained panel
			# directly so the next state is measured without it.
			_hud.toast("", "", 0.0)
			(_hud.get("_toast_panel") as Control).visible = false
		&"ship_rest_overlay":
			if is_instance_valid(_rest_overlay):
				_rest_overlay.call(&"end_rest")
		&"pause_menu", &"settings_menu", &"activity_board":
			_hud.set_paused(false)
	await process_frame


# --- Production configuration and camera ------------------------------------


## Records the shipping stretch configuration next to the measurements, because
## it is the one thing this suite must override to reach an ultrawide viewport.
func _report_production_stretch_policy() -> void:
	print("ULTRAWIDE_STRETCH_POLICY ", JSON.stringify({
		"stretch_mode": str(ProjectSettings.get_setting(
			"display/window/stretch/mode", "disabled"
		)),
		"stretch_aspect": str(ProjectSettings.get_setting(
			"display/window/stretch/aspect", "keep"
		)),
		"content_scale_size": [_restore_content_size.x, _restore_content_size.y],
		"letterboxes_non_16_9": str(ProjectSettings.get_setting(
			"display/window/stretch/aspect", "keep"
		)) == "keep",
	}))


## Godot's `Camera3D.KEEP_HEIGHT` is the project's vertical-FOV policy: the
## authored `fov` is the vertical angle and the horizontal angle widens with the
## display. `HeroShip._chase_camera_boundary_samples` already branches on it, so
## the first property under test is that both rigs stay on it.
##
## The rest is the ultrawide policy itself, measured on the live window rather
## than computed: the suite resizes to each supported display with the cap on and
## again with it off, reads `fov` back off the real `Camera3D`s, and asserts the
## table. Nothing re-pushes a FOV between resolutions -- the resize has to
## re-derive it, because a player dragging their window onto an ultrawide panel
## does not reopen the settings menu.
func _check_camera_field_of_view_policy() -> void:
	var ship := _game.get_node_or_null("TorrentInterceptor") as HeroShip
	_check(ship != null, "production Main exposes the hero ship camera rigs")
	if ship == null:
		return
	var chase := ship.get("_camera") as Camera3D
	var cockpit := ship.get("_cockpit_camera") as Camera3D
	_check(
		chase != null and cockpit != null
		and chase.keep_aspect == Camera3D.KEEP_HEIGHT
		and cockpit.keep_aspect == Camera3D.KEEP_HEIGHT,
		"both hero rigs keep the vertical FOV policy instead of a fixed horizontal angle"
	)
	if chase == null or cockpit == null:
		return
	_check(
		RuntimeSettingsType.DEFAULT_LIMIT_ULTRAWIDE_FOV
			== UltrawideFovPolicy.DEFAULT_LIMIT_ULTRAWIDE_FOV,
		"the shipping setting default and the policy default are the same value"
	)
	_check(
		RuntimeSettingsType.DEFAULT_LIMIT_ULTRAWIDE_FOV,
		"the ultrawide field-of-view limit ships enabled by default"
	)
	var report: Array = []
	for limit_enabled: bool in [true, false]:
		await _apply_resolution(Vector2i(1920, 1080))
		ship.set_camera_fov(AUTHORED_CAMERA_FOV, limit_enabled)
		for resolution in RESOLUTIONS:
			await _apply_resolution(resolution)
			var aspect := float(resolution.x) / float(resolution.y)
			var limited := limit_enabled and aspect > UltrawideFovPolicy.REFERENCE_ASPECT
			report.append({
				"resolution": "%dx%d" % [resolution.x, resolution.y],
				"aspect": snappedf(aspect, 0.001),
				"limit_ultrawide_fov": limit_enabled,
				"limited": limited,
				"chase_vertical_fov": snappedf(chase.fov, 0.01),
				"chase_horizontal_fov": snappedf(_horizontal_fov(chase.fov, aspect), 0.01),
				"cockpit_vertical_fov": snappedf(cockpit.fov, 0.01),
				"cockpit_horizontal_fov": snappedf(_horizontal_fov(cockpit.fov, aspect), 0.01),
			})
			_check(
				is_equal_approx(chase.fov, cockpit.fov),
				"%dx%d resolves one angle for both hero rigs%s"
					% [resolution.x, resolution.y, "" if limit_enabled else " (cap off)"]
			)
			_check(
				is_equal_approx(ship.get_authored_camera_fov(), AUTHORED_CAMERA_FOV),
				"%dx%d leaves the authored angle at %.0f degrees%s"
					% [
						resolution.x, resolution.y, AUTHORED_CAMERA_FOV,
						"" if limit_enabled else " (cap off)"
					]
			)
			if not limited:
				# Exact, not approximate: this is the promise that every display
				# at 21:9 or narrower renders precisely what it rendered before
				# the policy existed.
				_check(
					chase.fov == AUTHORED_CAMERA_FOV,
					"%dx%d keeps the authored vertical FOV bit-exact%s"
						% [
							resolution.x, resolution.y,
							"" if limit_enabled else " (cap off)"
						]
				)
				continue
			_check(
				chase.fov < AUTHORED_CAMERA_FOV,
				"%dx%d narrows the vertical angle instead of widening without limit"
					% [resolution.x, resolution.y]
			)
			_check(
				is_equal_approx(
					snappedf(_horizontal_fov(chase.fov, aspect), 0.01),
					snappedf(
						UltrawideFovPolicy.horizontal_fov_ceiling_degrees(
							AUTHORED_CAMERA_FOV
						),
						0.01
					)
				),
				"%dx%d holds the horizontal angle on the 21:9 ceiling (%.2f degrees)"
					% [
						resolution.x, resolution.y,
						_horizontal_fov(chase.fov, aspect)
					]
			)
	print("ULTRAWIDE_CAMERA_FOV ", JSON.stringify({
		"policy": "keep_height_vertical_fov_with_ultrawide_ceiling",
		"setting": "limit_ultrawide_fov",
		"default_enabled": RuntimeSettingsType.DEFAULT_LIMIT_ULTRAWIDE_FOV,
		"authored_vertical_fov": AUTHORED_CAMERA_FOV,
		"reference_aspect": snappedf(UltrawideFovPolicy.REFERENCE_ASPECT, 0.001),
		"horizontal_fov_ceiling": snappedf(
			UltrawideFovPolicy.horizontal_fov_ceiling_degrees(AUTHORED_CAMERA_FOV), 0.01
		),
		"clamp": [55.0, 110.0],
		"samples": report,
	}))
	await _apply_resolution(Vector2i(1920, 1080))
	ship.set_camera_fov(1000.0, true)
	_check(
		chase.fov <= 110.0 and cockpit.fov <= 110.0,
		"the shipping FOV clamp bounds both rigs"
	)
	ship.set_camera_fov(AUTHORED_CAMERA_FOV, true)


func _horizontal_fov(vertical_fov: float, aspect: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(vertical_fov) * 0.5) * aspect))


# --- Harness ----------------------------------------------------------------


func _accept_caption_request(_request: Dictionary) -> bool:
	return true


func _detail(items: Array) -> String:
	if items.is_empty():
		return ""
	return " (" + "; ".join(PackedStringArray(items)) + ")"


func _teardown() -> void:
	_hud.set_paused(false)
	_hud.unbind_caption_event_submitter(Callable(self, &"_accept_caption_request"))
	if is_instance_valid(_rest_overlay):
		_rest_overlay.call(&"end_rest")
		_rest_overlay.queue_free()
		_rest_overlay = null
	await process_frame
	_game.queue_free()
	_game = null
	_hud = null
	for frame in 3:
		await process_frame
	root.content_scale_aspect = _restore_aspect
	root.content_scale_size = _restore_content_size
	root.size = _restore_size
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("ULTRAWIDE_LAYOUT_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
