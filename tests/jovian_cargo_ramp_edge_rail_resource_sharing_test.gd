extends SceneTree

const JOVIAN_SCENE := preload("res://scenes/ships/jovian_light_freighter.tscn")
var _failures := PackedStringArray()

func _init() -> void:
 call_deferred("_run")

func _run() -> void:
 var ship := JOVIAN_SCENE.instantiate() as JovianLightFreighter
 root.add_child(ship)
 ship.set_physics_process(false)
 var hinge := ship.get_jovian_visual_root().get_node("CargoAccess/CargoRampHinge") as Node3D
 var batches: Array[MeshInstance3D] = []
 var resources: Array[Mesh] = []
 var all_match := true
 for toe in [false,true]:
  var frame := hinge.get_node("CargoToeHinge/ToeFrame" if toe else "MainFrame") as Node3D
  var source := ship.get("_cargo_ramp_toe_rail_mesh" if toe else "_cargo_ramp_edge_rail_mesh") as ArrayMesh
  var batch: MeshInstance3D
  for child: MeshInstance3D in frame.get_children():
   if child.mesh.surface_get_material(0) == ship.get_variant_materials().get("amber"):
    batch = child
  if batch == null:
   all_match = false
   continue
  batches.append(batch)
  resources.append(batch.mesh)
  var inner := JovianLightFreighter.CARGO_RAMP_SPLIT if toe else JovianLightFreighter.CARGO_RAMP_INNER
  var outer := JovianLightFreighter.CARGO_RAMP_OUTER if toe else JovianLightFreighter.CARGO_RAMP_SPLIT
  var actual := batch.mesh.get_faces()
  var expected := 0
  for z in [-1.58,1.58]:
   var pose := Transform3D(Basis(Vector3.BACK, atan2(1.73,4.725)),
    (inner+outer)*0.5 + JovianLightFreighter.CARGO_RAMP_DIRECTION*(0.0 if toe else 0.11)
    + JovianLightFreighter.CARGO_RAMP_NORMAL*0.09 + Vector3(0,0,z))
   for vertex in source.get_faces():
    all_match = all_match and _has_point(actual, pose*vertex)
    expected += 1
  all_match = all_match and batch.mesh.get_faces().size() == expected and batch.mesh.get_surface_count() == 1
  all_match = all_match and batch.material_override == null and batch.material_overlay == null and batch.visible and batch.layers == 1
 _check(all_match and batches.size()==2,"four exact authored rails batch into two amber leaf surfaces with no lost faces or extra material")
 ship.set("_landed",false)
 ship.call("_update_cargo_ramp_presentation",3.0)
 for index in batches.size():
  _check(batches[index].mesh==resources[index],"folding retains each immutable rail batch resource")
 ship.reset_for_reuse(ship.global_transform)
 await physics_frame
 for index in batches.size():
  _check(batches[index].mesh==resources[index],"reuse retains rail batches attached to their original rigid leaf")
 ship.queue_free()
 await process_frame
 if _failures.is_empty():
  print("JOVIAN_CARGO_RAMP_EDGE_RAIL_RESOURCE_SHARING_TEST_OK: four rails, two immutable batches")
  quit(0)
 else:
  printerr("JOVIAN_CARGO_RAMP_EDGE_RAIL_RESOURCE_SHARING_TEST_FAILED: ",_failures)
  quit(1)

func _has_point(points: PackedVector3Array, expected: Vector3) -> bool:
 for point in points:
  # SurfaceTool output rounds the emitted coordinates to 0.1 mm.
  if point.distance_squared_to(expected) < 0.0000000225:
   return true
 return false

func _check(condition: bool, message: String) -> void:
 if condition: print("PASS: ",message)
 else:
  _failures.append(message)
  push_error("FAIL: "+message)
