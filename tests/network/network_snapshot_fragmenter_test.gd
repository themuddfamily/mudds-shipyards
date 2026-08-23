extends SceneTree

const Fragmenter := preload("res://scripts/network/network_snapshot_fragmenter.gd")

func _init() -> void:
	var sender := Fragmenter.new()
	var receiver := Fragmenter.new()
	var packet := {"kind": &"delta", "revision": 4, "changes": {"blob": "x".repeat(1900)}}
	var fragments := sender.fragment(packet, 2, 4)
	assert(fragments.size() > 1)
	var duplicate := receiver.accept(fragments[0], 1)
	assert(duplicate.accepted and duplicate.status == &"fragment_buffered")
	assert(receiver.accept(fragments[0], 2).status == &"duplicate_or_mismatched_fragment")
	var complete: Dictionary = {}
	for index in range(1, fragments.size()):
		complete = receiver.accept(fragments[index], 3)
	assert(complete.accepted and complete.status == &"reassembled")
	assert((complete.packet as Dictionary).revision == 4)
	assert(receiver.accept(fragments[0], 4).status == &"stale_or_invalid_fragment")
	print("OK: network snapshot fragmenter (5 assertions)")
	quit(0)
