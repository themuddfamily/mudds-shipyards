extends SceneTree

## Holds the station's lettering to the geometry budget it was measured into.
##
## The failure this guards against is not dramatic, which is exactly why it needs
## a test: someone adds one more sign with hand-authored `TextMesh` settings, it
## costs ten thousand triangles, nobody notices, and eighteen months later the
## scene is a fifth lettering again. The ceilings below are the measured post-fix
## figures with deliberate headroom, not aspirations.

const WORLD_SCENE := preload("res://scenes/world/shipyard_world.tscn")

## Measured after the budget landed: 31 signs, 60,829 triangles, worst single
## sign 4,239. The ceilings carry roughly 30% headroom so that adding legitimate
## new signage does not trip the gate, while a return to unbudgeted `TextMesh`
## (which cost 315,360 across the same 31 signs) trips it immediately.
const TOTAL_SIGN_TRIANGLE_CEILING := 80_000
const PER_SIGN_TRIANGLE_CEILING := 6_000
## The census counted 31 live signs. Held as a floor, not an equality: signs may
## legitimately be added, and this suite exists to bound their cost, not their
## number.
const MINIMUM_SIGN_COUNT := 31

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_world_signs()
	_check_world_size_is_preserved()
	_check_sweep_is_idempotent()
	_finish()


func _check_world_signs() -> void:
	var world := WORLD_SCENE.instantiate() as ShipyardWorld
	_check(world != null, "production shipyard world instantiates")
	if world == null:
		return
	root.add_child(world)
	await process_frame

	var signs: Array[MeshInstance3D] = []
	_collect_signs(world, signs)
	_check(
		signs.size() >= MINIMUM_SIGN_COUNT,
		"world still carries its wayfinding lettering (%d signs, floor %d)" % [signs.size(), MINIMUM_SIGN_COUNT]
	)

	var total := 0
	var worst := 0
	var worst_text := ""
	var unbudgeted: Array[String] = []
	var empty_legends: Array[String] = []
	for instance in signs:
		var mesh := instance.mesh as TextMesh
		var triangles := SignGeometryBudget.triangles_of(mesh)
		total += triangles
		if triangles > worst:
			worst = triangles
			worst_text = mesh.text
		if mesh.font_size != SignGeometryBudget.FONT_SIZE or not is_equal_approx(mesh.depth, SignGeometryBudget.DEPTH):
			unbudgeted.append("%s (font %d, depth %.3f)" % [instance.name, mesh.font_size, mesh.depth])
		if mesh.text.strip_edges().is_empty():
			empty_legends.append(str(instance.get_path()))

	_check(
		unbudgeted.is_empty(),
		"every live sign is under the shared geometry budget%s" % ("" if unbudgeted.is_empty() else ": " + "; ".join(unbudgeted))
	)
	_check(
		empty_legends.is_empty(),
		"the budget sweep never blanks a legend%s" % ("" if empty_legends.is_empty() else ": " + "; ".join(empty_legends))
	)
	_check(
		total <= TOTAL_SIGN_TRIANGLE_CEILING,
		"station lettering stays inside its triangle budget (%d of %d)" % [total, TOTAL_SIGN_TRIANGLE_CEILING]
	)
	_check(
		worst <= PER_SIGN_TRIANGLE_CEILING,
		"no single sign exceeds the per-sign ceiling (worst %d, \"%s\", limit %d)" % [
			worst, worst_text, PER_SIGN_TRIANGLE_CEILING,
		]
	)

	world.queue_free()
	await process_frame


## The saving is only acceptable because it does not resize anything. A sign that
## shrinks is a sign that no longer fits the panel it was placed on.
func _check_world_size_is_preserved() -> void:
	var legends := [
		"MUDDS  //  REGENERATION DECK",
		"KATANA  PARADOX  PREDATOR  DYNAMIC",
		"CINDER REACH DOCK GATE",
	]
	for legend: String in legends:
		var authored := TextMesh.new()
		authored.text = legend
		# The settings every sign builder in the project used before the budget.
		authored.font_size = 64
		authored.pixel_size = 0.012
		authored.depth = 0.025
		authored.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		authored.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var budgeted := SignGeometryBudget.build(legend)
		var before := authored.get_aabb().size
		var after := budgeted.get_aabb().size

		# Tolerances are relative, and they are not zero, because a font is
		# hinted: advance widths and the ascent/descent box are rounded to whole
		# font pixels, and 48 pixels round differently from 64. Measured drift is
		# 0.2-0.4% narrower and 2.9% taller before node scale. On the widest sign
		# in the game that is 2 cm off the width; on the tallest lettering block
		# it is 8 cm of extra height on a 3.4 m board. Both stay inside the panel
		# each legend sits on, which is the property that actually matters, and a
		# sign that moved by more than this would be a real placement regression
		# rather than a rounding artefact.
		_check(
			absf(before.x - after.x) / before.x <= 0.005,
			"\"%s\" keeps its width (%.4f m -> %.4f m)" % [legend, before.x, after.x]
		)
		_check(
			after.x <= before.x,
			"\"%s\" never grows wider than its authored block" % legend
		)
		_check(
			absf(before.y - after.y) / before.y <= 0.035,
			"\"%s\" keeps its height (%.4f m -> %.4f m)" % [legend, before.y, after.y]
		)
		_check(
			after.z <= 0.0001,
			"\"%s\" carries no glyph extrusion (%.4f m)" % [legend, after.z]
		)


## The world sweeps its whole subtree on build. If the sweep were not a no-op on
## already-budgeted meshes it would keep shrinking lettering on every re-entry.
func _check_sweep_is_idempotent() -> void:
	var holder := Node3D.new()
	var instance := MeshInstance3D.new()
	instance.mesh = SignGeometryBudget.build("BERTH 03  //  CLEAR")
	holder.add_child(instance)

	var first := SignGeometryBudget.normalise_tree(holder)
	var second := SignGeometryBudget.normalise_tree(holder)
	_check(int(first["signs"]) == 1 and int(second["signs"]) == 1, "the sweep finds the sign on every pass")
	_check(
		int(first["triangles_before"]) == int(first["triangles_after"]),
		"sweeping an already-budgeted sign changes nothing"
	)
	_check(
		int(second["triangles_after"]) == int(first["triangles_after"]),
		"a second sweep is a no-op rather than a further reduction"
	)
	holder.free()


func _collect_signs(node: Node, into: Array[MeshInstance3D]) -> void:
	var instance := node as MeshInstance3D
	if instance != null and instance.mesh is TextMesh:
		into.append(instance)
	for child in node.get_children():
		_collect_signs(child, into)


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("SIGN_GEOMETRY_BUDGET_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("SIGN_GEOMETRY_BUDGET_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
