extends SceneTree

## Focused presentation test and Forward+ review frame for the existing Jovian
## kit-delivery terminal. State meaning is carried by steady text as well as
## colour, so the reduced-flash frame keeps the same semantic hierarchy.

const TERMINAL_SCENE := preload(
	"res://scenes/world/modules/cargo_destination_terminal.tscn"
)
const OUTPUT_DIR := "/tmp/mudds-wave32-cargo-terminal-visual/artifacts/cargo_terminal_states"

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var reduced_flash := "--reduced-flash" in OS.get_cmdline_user_args()
	var capture_requested := "--capture" in OS.get_cmdline_user_args()
	var stage := Node3D.new()
	stage.name = "CargoTerminalReadabilityFixture"
	root.add_child(stage)
	_add_environment(stage)
	_add_deck(stage)

	var states: Array[StringName] = [&"ready", &"committed", &"stale_rejected"]
	var positions := [-5.2, 0.0, 5.2]
	var expected_tokens: Array[StringName] = [
		&"ready", &"transfer_accepted", &"terminal_error",
	]
	var required_words := ["READY", "ACCEPTED", "ERROR"]
	var terminals: Array[CargoTransferTerminal] = []
	for state_index in states.size():
		var terminal := TERMINAL_SCENE.instantiate() as CargoTransferTerminal
		terminal.position = Vector3(positions[state_index], 0.0, 0.0)
		stage.add_child(terminal)
		terminals.append(terminal)
		var descendants_before := terminal.find_children("*", "", true, false).size()
		var interaction_before := terminal.get_interaction_snapshot(
			terminal.to_global(CargoTransferTerminal.INTERACTION_ORIGIN),
			terminal.get_terminal_generation()
		)
		var applied := terminal.apply_cargo_presentation_snapshot({
			"terminal_id": terminal.terminal_id,
			"terminal_generation": terminal.get_terminal_generation(),
			"state_id": states[state_index],
			"reduced_flash": reduced_flash,
		})
		var presentation := terminal.get_cargo_presentation_state()
		var label := terminal.get_node(^"TerminalLabel") as Label3D
		var interaction_after := terminal.get_interaction_snapshot(
			terminal.to_global(CargoTransferTerminal.INTERACTION_ORIGIN),
			terminal.get_terminal_generation()
		)
		_check(
			bool(applied.get("accepted", false))
			and StringName(presentation.get("state_token", &"")) == expected_tokens[state_index]
			and label.text.contains(required_words[state_index])
			and label.text.contains("\n")
			and not bool(presentation.get("flashing", true))
			and presentation.get("presentation_behavior") == &"steady_text_and_color",
			"%s has a unique steady text token independent of colour" % states[state_index]
		)
		_check(
			float(presentation.get("emission_energy", INF)) <= (
				CargoTransferTerminal.REDUCED_FLASH_EMISSION_CAP
				if reduced_flash else CargoTransferTerminal.MAX_PRESENTATION_EMISSION_ENERGY
			)
			and bool(presentation.get("reduced_flash", not reduced_flash)) == reduced_flash,
			"%s respects the selected bounded emission profile" % states[state_index]
		)
		_check(
			terminal.find_children("*", "", true, false).size() == descendants_before
			and terminal.find_children("*", "Light3D", true, false).is_empty()
			and terminal.get_interaction_snapshot(
				terminal.to_global(CargoTransferTerminal.INTERACTION_ORIGIN),
				terminal.get_terminal_generation()
			) == interaction_after
			and interaction_after == interaction_before
			and terminal.get_interaction_prompt().is_empty(),
			"%s changes no nodes, lights, prompt, interaction, or terminal generation" % states[state_index]
		)

	_check(
		terminals[0].get_cargo_presentation_state().state_token
		!= terminals[1].get_cargo_presentation_state().state_token
		and terminals[1].get_cargo_presentation_state().state_token
		!= terminals[2].get_cargo_presentation_state().state_token,
		"ready, accepted, and error remain semantically distinct without colour"
	)

	if capture_requested:
		_add_camera(stage)
		var banner := Label.new()
		banner.position = Vector2(34.0, 24.0)
		banner.add_theme_font_size_override("font_size", 28)
		banner.add_theme_color_override("font_color", Color("e7f2f6"))
		var profile_name := "REDUCED FLASH (STATIC)" if reduced_flash else "STANDARD"
		banner.text = "JOVIAN KIT DELIVERY TERMINAL  //  %s" % profile_name
		root.add_child(banner)
		# Leave enough rendered frames for all three instance materials and glyph
		# atlases to finish compiling under the software Forward+ review device.
		for _frame in 40:
			await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
		var file_name := "reduced_flash.png" if reduced_flash else "standard.png"
		var image := root.get_texture().get_image()
		var error := image.save_png(OUTPUT_DIR.path_join(file_name))
		_check(error == OK, "Forward+ review frame saves for %s" % file_name)

	stage.queue_free()
	await process_frame
	_finish()


func _add_environment(stage: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("060b10")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7f929e")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	world_environment.environment = environment
	stage.add_child(world_environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -25.0, 0.0)
	key.light_color = Color("d9e8ee")
	key.light_energy = 1.05
	key.shadow_enabled = true
	stage.add_child(key)


func _add_deck(stage: Node3D) -> void:
	var deck := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(17.0, 0.18, 7.5)
	deck.mesh = mesh
	deck.position = Vector3(0.0, -0.28, 0.45)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("29343c")
	material.metallic = 0.34
	material.roughness = 0.7
	deck.material_override = material
	stage.add_child(deck)


func _add_camera(stage: Node3D) -> void:
	root.size = Vector2i(1600, 900)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0.0, 4.3, 12.0)
	camera.fov = 54.0
	camera.look_at(Vector3(0.0, 0.65, -0.2), Vector3.UP)
	camera.current = true


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	print("CARGO_TRANSFER_TERMINAL_STATE_READABILITY_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CARGO_TRANSFER_TERMINAL_STATE_READABILITY_TEST_OK")
		quit(0)
	else:
		quit(1)
