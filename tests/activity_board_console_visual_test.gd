extends SceneTree

const ActivityBoardConsoleType := preload("res://scripts/interaction/activity_board_console.gd")

var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var console := ActivityBoardConsoleType.new()
	root.add_child(console)
	await process_frame

	var visuals := console.get_node_or_null(^"ActivityBoardReadability") as Node3D
	var header := console.get_node_or_null(
		^"ActivityBoardReadability/ActivityBoardHeader"
	) as MeshInstance3D
	var underline := console.get_node_or_null(
		^"ActivityBoardReadability/ActivityBoardLocatorUnderline"
	) as MeshInstance3D
	_check(
		visuals != null and bool(visuals.get_meta("presentation_only", false)),
		"console owns one explicitly presentation-only readability group"
	)
	_check(
		header != null
		and header.mesh is TextMesh
		and (header.mesh as TextMesh).text == "ACTIVITY BOARD"
		and (header.material_override as StandardMaterial3D).emission_enabled
		and (header.material_override as StandardMaterial3D).emission_energy_multiplier >= 1.3,
		"angled display carries a bright, literal Activity Board header"
	)
	var header_basis := header.basis.orthonormalized() if header != null else Basis.IDENTITY
	var interaction_direction := Vector3(0.0, 0.0, -1.0)
	var display_away_direction := Vector3(0.0, 0.0, 1.0)
	_check(
		header != null
		and header_basis.z.dot(interaction_direction) > 0.2
		and header_basis.y.dot(display_away_direction) > 0.95
		and header_basis.y.y > 0.0
		and header_basis.x.dot(Vector3.LEFT) > 0.99,
		"header faces the interaction side while glyph-up runs away along the display without mirroring"
	)
	_check(
		underline != null
		and underline.mesh is BoxMesh
		and (underline.mesh as BoxMesh).size.is_equal_approx(Vector3(1.18, 0.014, 0.025))
		and (underline.material_override as StandardMaterial3D).emission_enabled
		and (underline.position - header.position).dot(header_basis.y) < 0.0,
		"header retains its high-contrast amber locator underline"
	)
	_check(
		console.get_node_or_null(^"InteractionCollision") is CollisionShape3D
		and console.get_child_count() == 2
		and visuals.get_child_count() == 2,
		"readability polish adds only two visual leaves beside the unchanged interaction shape"
	)

	var open_events: Array[Node] = []
	console.open_requested.connect(func(actor_node: Node) -> void: open_events.append(actor_node))
	var actor := Node.new()
	root.add_child(actor)
	_check(
		console.interact(actor) and open_events == [actor],
		"valid interaction still emits one open request"
	)
	_check(
		not console.interact(null) and open_events == [actor],
		"invalid interaction still changes no board state"
	)
	_check(
		console.get_interaction_prompt() == "[ E ]  ACCESS ACTIVITY BOARD",
		"existing interaction prompt remains unchanged"
	)

	console.queue_free()
	actor.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ACTIVITY_BOARD_CONSOLE_VISUAL_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("FAIL: " + message)
