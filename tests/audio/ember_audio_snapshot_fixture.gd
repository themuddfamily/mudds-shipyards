extends EmberSurfaceLoopProductionBinding

## Audio fixtures supply accepted owner observations through the real guarded
## notification path. Ordinary runtime owners build these observations themselves.
var observation := {"generation": 0, "state_id": &"idle"}
var full_snapshot_reads := 0
var audio_snapshot_reads := 0

func get_snapshot() -> Dictionary:
	full_snapshot_reads += 1
	return observation.duplicate(true)

func get_audio_presentation_snapshot() -> Dictionary:
	audio_snapshot_reads += 1
	return observation.duplicate(true)

func publish(snapshot: Dictionary) -> void:
	observation = snapshot.duplicate(true)
	_finish_late_signal(&"fixture_observation")
