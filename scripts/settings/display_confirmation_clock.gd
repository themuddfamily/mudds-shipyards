extends Node

## Display recovery must advance even while gameplay and its owner are paused.
signal elapsed(delta: float)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	elapsed.emit(delta)
