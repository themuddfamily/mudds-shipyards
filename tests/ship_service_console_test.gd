extends SceneTree

const ConsoleType := preload("res://scripts/interaction/ship_service_console.gd")

var _failures := PackedStringArray()
var _assertions := 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var console = ConsoleType.new()
	root.add_child(console)
	await process_frame

	var header := console.get_node_or_null(
		^"ShipServiceReadability/ShipServiceHeader"
	) as Label3D
	var status := console.get_node_or_null(
		^"ShipServiceReadability/ShipServiceStatus"
	) as Label3D
	_check(
		header != null and header.text == "SHIP SERVICES"
			and status != null and status.text == ConsoleType.INITIAL_STATUS_TEXT
			and header.font_size == 47 and status.font_size == 47
			and is_equal_approx(header.font_size * header.pixel_size, 0.768)
			and is_equal_approx(status.font_size * status.pixel_size, 0.768)
			and header.outline_size == 0 and status.outline_size == 0
			and not header.double_sided and not status.double_sided
			and not header.shaded and not status.shaded
			and not header.no_depth_test and not status.no_depth_test
			and header.modulate == ConsoleType.CYAN and status.modulate == ConsoleType.AMBER
			and header.position == ConsoleType.HEADER_POSITION
			and status.position == ConsoleType.STATUS_POSITION
			and header.basis.is_equal_approx(Basis(ConsoleType.GLYPH_RIGHT,
				ConsoleType.GLYPH_UP, ConsoleType.FACE_NORMAL).scaled(Vector3.ONE * ConsoleType.HEADER_SCALE))
			and status.basis.is_equal_approx(Basis(ConsoleType.GLYPH_RIGHT,
				ConsoleType.GLYPH_UP, ConsoleType.FACE_NORMAL).scaled(Vector3.ONE * ConsoleType.STATUS_SCALE)),
		"the authored workstation names its service and starts with physical usage guidance"
	)
	_check(
		console.get_node_or_null(^"InteractionCollision") is CollisionShape3D
			and console.get_interaction_prompt().contains("RESTOCK ACTIVE SHIP"),
		"the service display is discoverable through the common station interaction layer"
	)
	var authority := console.get_presentation_snapshot().get("authority", {}) as Dictionary
	_check(
		not bool(authority.get("repair", true))
			and not bool(authority.get("resource", true))
			and not bool(authority.get("damage", true))
			and not bool(authority.get("ship_lifecycle", true)),
		"the console explicitly owns presentation rather than repair or ship authority"
	)

	var actor := Node.new()
	root.add_child(actor)
	var requests: Array[Node] = []
	console.service_requested.connect(
		func(request_actor: Node) -> void: requests.append(request_actor)
	)
	_check(
		console.interact(actor) and requests == [actor],
		"one valid physical interaction emits one detached service request"
	)
	_check(
		not console.interact(null) and requests == [actor],
		"an invalid actor cannot emit or mutate a service request"
	)

	var presented: Dictionary = console.present_service_result({
		"accepted": true,
		"reason": &"resource_restocked",
		"display_name": "Jovian Light Freighter",
		"resource_units": 6,
		"resource_capacity": 6,
		"units_added": 1,
	})
	_check(
		bool(presented.get("accepted", false))
			and str(presented.get("text", "")).contains("RESTOCKED")
			and str(presented.get("text", "")).contains("KITS 6/6")
			and status.text == presented.get("text", ""),
		"an accepted restock becomes literal craft and kit-count feedback on the physical label"
	)
	var full: Dictionary = console.present_service_result({
		"accepted": true,
		"reason": &"resource_already_full",
		"display_name": "Halyard Crew Transport",
		"resource_units": 6,
		"resource_capacity": 6,
		"units_added": 0,
	})
	_check(
		str(full.get("text", "")).contains("FULL")
			and str(full.get("text", "")).contains("HALYARD CREW TRANSPORT"),
		"a full locker is an explicit no-op rather than a false restock claim"
	)
	var rejected: Dictionary = console.present_service_result({
		"accepted": false,
		"reason": &"unsupported_ship",
	})
	_check(
		str(rejected.get("text", "")).contains("JOVIAN // HALYARD // BULWARK"),
		"unsupported craft feedback names the three serviceable choices"
	)
	var sequence_before := int(
		console.get_presentation_snapshot().get("presentation_sequence", -1)
	)
	_check(
		console.present_service_result({
			"accepted": true,
			"reason": &"resource_restocked",
			"resource_units": 7,
			"resource_capacity": 6,
			"units_added": 1,
		}).get("reason", &"") == &"invalid_service_resources"
			and int(console.get_presentation_snapshot().get("presentation_sequence", -2)) \
				== sequence_before,
		"malformed kit counts cannot repaint or advance the physical display"
	)

	console.queue_free()
	actor.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SHIP_SERVICE_CONSOLE_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("FAIL: " + message)
