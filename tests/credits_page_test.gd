extends SceneTree

## The CREDITS page: reachable from the startup menu and the pause menu, keyboard
## and controller focus with Esc/B returning to the opener, scrollable without a
## mouse, and carrying the version footer, the Godot MIT licence, the Godot
## third-party notices and one attribution for every ASSETS.md register entry.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const Catalog := preload("res://scripts/ui/credits_catalog.gd")
const SafeArea := preload("res://scripts/ui/ultrawide_safe_area_contract.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame
	var pause := hud.get("_pause") as Control
	var page := hud.find_child("CreditsPage", true, false) as Control
	var scroll := hud.find_child("CreditsScroll", true, false) as ScrollContainer
	var intro_button := hud.find_child("IntroCreditsButton", true, false) as Button
	var pause_button := hud.find_child("CreditsOpenButton", true, false) as Button
	var back_button := hud.find_child("CreditsBackButton", true, false) as Button
	var notices_button := hud.find_child("CreditsEngineNoticesButton", true, false) as Button
	_check(
		page != null and scroll != null and intro_button != null and pause_button != null
		and back_button != null and notices_button != null,
		"the credits page, its entry buttons and its controls exist",
	)
	_check(
		page.get_parent() == hud.get("_pause_panels"),
		"credits live in the pause layer's scaled panels, so UI scale applies",
	)

	# --- Startup menu -------------------------------------------------------
	_check(
		intro_button.focus_mode == Control.FOCUS_ALL
		and not intro_button.focus_neighbor_top.is_empty(),
		"the startup CREDITS button is on the controller focus path",
	)
	intro_button.emit_signal(&"pressed")
	await process_frame
	_check(
		hud.is_credits_page_open() and hud.is_credits_opened_from_intro()
		and pause.visible and page.visible
		and root.gui_get_focus_owner() == scroll,
		"CREDITS opens from the startup menu with focus on the scroll region",
	)
	hud._unhandled_input(_action(&"interact"))
	_check(
		not bool(hud.get("_started")) and hud.is_credits_page_open(),
		"a begin-shift key pressed over Credits does not start the shift",
	)
	hud._unhandled_input(_action(&"pause"))
	await process_frame
	_check(
		not hud.is_credits_page_open() and not pause.visible
		and not bool(hud.get("_started"))
		and root.gui_get_focus_owner() == intro_button,
		"Esc returns from Credits to the startup menu with focus on CREDITS",
	)

	# --- Pause menu ----------------------------------------------------------
	hud.set("_started", true)
	hud.set_paused(true)
	await process_frame
	_check(
		pause_button.is_visible_in_tree() and pause_button.focus_mode == Control.FOCUS_ALL
		and not pause_button.focus_neighbor_left.is_empty(),
		"the pause menu offers a controller-focusable CREDITS button",
	)
	pause_button.emit_signal(&"pressed")
	await process_frame
	var main_page := hud.get("_pause_main_page") as Control
	_check(
		page.visible and not main_page.visible and not hud.is_credits_opened_from_intro()
		and root.gui_get_focus_owner() == scroll,
		"CREDITS opens from the pause menu and replaces the main pause page",
	)

	# Keyboard/D-pad scrolling on the focused region.
	await process_frame
	var before: int = scroll.scroll_vertical
	scroll._gui_input(_action(&"ui_down"))
	_check(scroll.scroll_vertical > before, "Down scrolls the credits text")
	scroll._gui_input(_action(&"ui_up"))
	_check(scroll.scroll_vertical == before, "Up scrolls it back")

	# Content.
	var text := _all_label_text(page)
	var footer := hud.find_child("CreditsVersionFooter", true, false) as Label
	_check(
		footer != null and footer.text.contains("MUDDS SHIPYARDS")
		and footer.text.contains(Catalog.project_version()),
		"the footer names the game and its version",
	)
	_check(
		text.contains(Catalog.TEAM_NAME) and text.contains("Godot Engine")
		and text.contains("Blender"),
		"the team, engine and tools are credited",
	)
	_check(
		text.contains(Engine.get_license_text().strip_edges())
		and text.contains("Permission is hereby granted"),
		"Godot's MIT licence notice is reproduced in full",
	)
	var registers := _assets_md_registers()
	_check(registers.size() >= 29, "ASSETS.md register headings were parsed (%d)" % registers.size())
	var missing: PackedStringArray = []
	for register in registers:
		if not Catalog.asset_registers().has(register) or not text.contains(register):
			missing.append(register)
	_check(
		missing.is_empty(),
		"every ASSETS.md entry is attributed on the page%s" % (
			"" if missing.is_empty() else " -- missing: " + ", ".join(missing)
		),
	)

	# Collapsible Godot third-party notices.
	var notices := hud.find_child("CreditsEngineNotices", true, false) as Control
	_check(notices != null and not notices.visible, "the Godot third-party notices start collapsed")
	notices_button.emit_signal(&"pressed")
	await process_frame
	var notice_text := _all_label_text(notices)
	var first_component := str((Engine.get_copyright_info()[0] as Dictionary).get("name", ""))
	var license_names := Engine.get_license_info().keys()
	_check(
		notices.visible and notice_text.contains(first_component)
		and notice_text.contains(str(license_names[0])),
		"expanding shows the engine component notices and licence texts",
	)
	notices_button.emit_signal(&"pressed")
	_check(not notices.visible, "the notices collapse again")

	# High contrast repaints the page's text.
	hud.set_high_contrast_hud(true)
	var sample := _first_label(page)
	_check(
		sample != null and sample.has_theme_constant_override(&"outline_size"),
		"high contrast adds the body-text outline to credits labels",
	)
	hud.set_high_contrast_hud(false)

	# Ultrawide: the page stays inside the centred readable band.
	for viewport: Vector2 in [Vector2(1280.0, 720.0), Vector2(3440.0, 1440.0), Vector2(5120.0, 1440.0)]:
		hud.layout_for_viewport(viewport)
		await process_frame
		await process_frame
		var page_rect: Rect2 = page.get_global_transform() * Rect2(Vector2.ZERO, page.size)
		var band := SafeArea.safe_rect(viewport, 1.0)
		_check(
			page_rect.position.x >= band.position.x - 1.0 and page_rect.end.x <= band.end.x + 1.0
			and page_rect.position.y >= 0.0 and page_rect.end.y <= viewport.y,
			"credits stay inside the %.0fx%.0f readable band" % [viewport.x, viewport.y],
		)

	# Controller B returns to the pause main page with focus on CREDITS.
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	hud._unhandled_input(back)
	await process_frame
	_check(
		not page.visible and main_page.visible and pause.visible
		and root.gui_get_focus_owner() == pause_button,
		"pad B returns from Credits to the pause menu with focus on CREDITS",
	)
	# Unpausing with Credits open never leaves it stranded.
	pause_button.emit_signal(&"pressed")
	hud.set_paused(false)
	_check(not page.visible and main_page.visible, "closing the pause overlay retires Credits")
	# The BACK button follows the same route.
	hud.set_paused(true)
	pause_button.emit_signal(&"pressed")
	back_button.emit_signal(&"pressed")
	_check(not page.visible and main_page.visible, "BACK returns to the pause menu")
	hud.set_paused(false)

	root.remove_child(hud)
	hud.queue_free()
	await process_frame
	if _failures.is_empty():
		print("CREDITS_PAGE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


## ASSETS.md headings (## and ###) with Markdown backticks removed.
func _assets_md_registers() -> PackedStringArray:
	var registers := PackedStringArray()
	var file := FileAccess.open("res://ASSETS.md", FileAccess.READ)
	if file == null:
		return registers
	while not file.eof_reached():
		var line := file.get_line()
		if not line.begins_with("## ") and not line.begins_with("### "):
			continue
		registers.append(line.lstrip("#").strip_edges().replace("`", ""))
	return registers


func _all_label_text(node: Node) -> String:
	var parts := PackedStringArray()
	for child in node.find_children("*", "Label", true, false):
		parts.append((child as Label).text)
	return "\n".join(parts)


func _first_label(node: Node) -> Label:
	var labels := node.find_children("*", "Label", true, false)
	return labels[0] as Label if not labels.is_empty() else null


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)
