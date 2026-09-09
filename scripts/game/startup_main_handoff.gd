extends RefCounted

## Loaded only after Boot's owned Main resource worker has returned. Keeping
## these concrete game types here lets the loading screen compile and present
## without synchronously loading the game and its preloaded ship resources.
var _flow: GameFlow


func prepare(main: Node, graphics_profile: int) -> bool:
	# The saved profile shapes the world's first construction frames.
	var world := main.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	if world != null:
		world.visual_quality_level = graphics_profile
	_flow = main as GameFlow
	return _flow != null and _flow.prepare_staged_startup()


func run_staged(on_stage: Callable) -> bool:
	return await _flow.run_staged_startup(on_stage)
