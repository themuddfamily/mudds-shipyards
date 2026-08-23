extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const GameFlowScript := preload("res://scripts/game/game_flow.gd")
const HeroShipScript := preload("res://scripts/ships/hero_ship.gd")
const HostScript := preload("res://scripts/world/ember_surface_loop_host.gd")
const BerthScript := preload("res://scripts/world/ember_surface_berth.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var main := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(main)
	main._resolve_scene_bindings()
	var host := main.get_node_or_null(^"EmberSurfaceLoopHost")
	var berth := main.get_node_or_null(^"EmberSurfaceBerth")
	var binding := main.get_node_or_null(^"EmberSurfaceLoopProductionBinding")
	var torrent := main.get_node_or_null(^"TorrentInterceptor")
	var valid := main is GameFlowScript \
			and host is HostScript \
			and berth is BerthScript \
			and binding != null \
			and torrent is HeroShipScript \
			and main.get_node_or_null(^"ArrowReconShip") != torrent \
			and main.find_children("EmberSurfaceLoopHost", "EmberSurfaceLoopHost", true, false).size() == 1 \
			and main.find_children("EmberSurfaceBerth", "EmberSurfaceBerth", true, false).size() == 1
	main.free()
	await process_frame
	if not valid:
		push_error("Ember Main host composition is not singular or does not reuse Torrent")
		quit(1)
		return
	print("EMBER_SURFACE_LOOP_MAIN_COMPOSITION_TEST_OK: one deferred host reuses Torrent")
	quit(0)
