extends SceneTree

## Focused proof of the Phase 10 section 2 perf-trim (2026-09-27):
##
## * the Torrent now runs `ShipFitoutBatch` over its own visual as the last step
##   of its build, like every fleet craft, and its frozen render allocation
##   roster still reads exactly what the craft allocates;
## * the shared cockpit restraint / seat-shell family left the protected-name
##   roster and folds in every craft that inherits the `HeroShip` cockpit, while
##   its consumers resolve it through `find_authored_pieces()`;
## * no collider, marker or interaction node is ever inside a batch.

# Resolve the concrete subtype before shared HeroShip references to avoid retained script resources.
const ArrowShipType := preload("res://scripts/ships/arrow_recon_ship.gd")
const BATCH := preload("res://scripts/rendering/ship_fitout_batch.gd")
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")

const RESTRAINT_PATTERN := "*Belt*"
const RESTRAINT_PIECES := 5

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(label)


func _run() -> void:
	_test_glob_lookup_answers_batched_and_live_pieces()
	await _test_torrent_consolidates_its_own_fitout()
	await _test_fleet_cockpit_restraints_fold()

	if _failures.is_empty():
		print("TORRENT_FITOUT_CONSOLIDATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL: %s" % failure)
	printerr("TORRENT_FITOUT_CONSOLIDATION_TEST_FAILED: %d of %d assertions failed" % [
		_failures.size(), _assertions
	])
	quit(1)


func _stock(size: Vector3, material: Material) -> ArrayMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	var tool := SurfaceTool.new()
	tool.create_from(mesh, 0)
	var array_mesh := tool.commit()
	array_mesh.surface_set_material(0, material)
	return array_mesh


func _batches(search_root: Node) -> Array[Node]:
	var found: Array[Node] = []
	for candidate in search_root.find_children("*", "MeshInstance3D", true, false):
		if candidate.has_meta(BATCH.BATCH_META):
			found.append(candidate)
	return found


## `find_authored_pieces()` is the index-aware `find_children(glob)`: folded
## pieces still answer, a batch never answers as a piece of its own.
func _test_glob_lookup_answers_batched_and_live_pieces() -> void:
	var craft := Node3D.new()
	craft.name = "GlobFixture"
	root.add_child(craft)
	var material := StandardMaterial3D.new()
	for index in 3:
		var belt := MeshInstance3D.new()
		belt.name = "FixtureBelt%d" % index
		belt.position = Vector3(float(index) * 0.3, 0.0, 0.0)
		belt.mesh = _stock(Vector3(0.1, 0.02, 0.4), material)
		craft.add_child(belt)
	var kept := MeshInstance3D.new()
	kept.name = "FixtureBeltKept"
	kept.position = Vector3(0.0, 0.5, 0.0)
	kept.mesh = _stock(Vector3(0.1, 0.02, 0.4), material)
	craft.add_child(kept)
	_check(BATCH.count_authored_pieces(craft, "FixtureBelt*") == 4, "four live pieces answer before the pass")
	var report := BATCH.consolidate([craft], PackedStringArray(["FixtureBeltKept"]), root)
	_check(int(report.visual_batches) == 1 and int(report.visual_sources) == 3, "the three unprotected pieces fold")
	_check(craft.find_children("FixtureBelt?", "MeshInstance3D", false, false).is_empty(), "no folded piece is still a node")
	var found := BATCH.find_authored_pieces(craft, "FixtureBelt*")
	var batched := 0
	for record in found:
		batched += 1 if bool(record.get("batched", false)) else 0
	_check(found.size() == 4 and batched == 3, "the glob still answers all four pieces, three of them from the index")
	_check(BATCH.count_authored_pieces(craft, "*") == 4, "a batch is never counted as an authored piece of its own")
	root.remove_child(craft)
	craft.free()


func _test_torrent_consolidates_its_own_fitout() -> void:
	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	root.add_child(torrent)
	await process_frame
	await physics_frame
	var report := torrent.get_torrent_fitout_consolidation_report()
	_check(bool(report.get("applied", false)), "the Torrent runs the fitout pass over its own visual")
	_check(
		int(report.get("removed_nodes", 0)) > int(report.get("added_nodes", 0)),
		"the Torrent's scene tree shrinks (removed %d, added %d)"
			% [int(report.get("removed_nodes", 0)), int(report.get("added_nodes", 0))]
	)
	var allocation := torrent.get_torrent_render_allocation_report()
	_check(
		bool(allocation.get("exact_counts", false)),
		"the frozen Torrent render roster still reads what the craft allocates"
	)
	_check(
		bool(torrent.get_torrent_art_audit_report().get("valid", false)),
		"the Torrent art audit (restraints, service panels, collision envelope) stays valid"
	)
	var visual := torrent.get_variant_visual_root()
	var cockpit := visual.get_node_or_null("CockpitInterior") as Node3D
	_check(
		cockpit != null and BATCH.count_authored_pieces(cockpit, RESTRAINT_PATTERN) == RESTRAINT_PIECES,
		"all five harness webbing runs are still counted through the piece index"
	)
	_check(
		cockpit != null and cockpit.find_children(RESTRAINT_PATTERN, "MeshInstance3D", true, false).is_empty(),
		"the harness webbing is folded rather than standing as five nodes"
	)
	var modern := visual.get_node_or_null("LegacyFarPresentation/ModernSystems") as Node3D
	var engines := modern.find_children("*EngineAssembly", "Node3D", true, false) if modern != null else []
	_check(engines.size() == 2, "both engine assemblies remain addressable")
	for engine in engines:
		_check(
			BATCH.count_authored_pieces(engine, "TurbineStatorVane*") == 8,
			"%s still answers eight stator vanes" % engine.name
		)
	for batch in _batches(torrent):
		_check(batch.get_child_count() == 0, "%s owns no child node" % batch.name)
		_check(
			batch.find_children("*", "CollisionObject3D", true, false).is_empty()
				and batch.find_children("*", "CollisionShape3D", true, false).is_empty(),
			"%s carries no collision authority" % batch.name
		)
	for authority in ["HullCollision", "WingCollision", "BoardingPoint", "ExitPoint", "LeftMuzzle"]:
		_check(torrent.get_node_or_null(authority) != null, "%s keeps its own node" % authority)
	torrent.queue_free()
	await process_frame


func _test_fleet_cockpit_restraints_fold() -> void:
	var arrow := ARROW_SCENE.instantiate() as HeroShip
	root.add_child(arrow)
	await process_frame
	await physics_frame
	_check(
		arrow.get_torrent_fitout_consolidation_report().is_empty(),
		"a fleet variant never runs the Torrent's own pass"
	)
	var visual := arrow.get_variant_visual_root()
	_check(
		BATCH.count_authored_pieces(visual, RESTRAINT_PATTERN) == RESTRAINT_PIECES,
		"the Arrow's inherited cockpit still answers all five harness webbing runs"
	)
	_check(
		visual.find_children(RESTRAINT_PATTERN, "MeshInstance3D", true, false).size() < RESTRAINT_PIECES,
		"the Arrow folds its inherited harness webbing now that the family left the roster"
	)
	arrow.queue_free()
	await process_frame
