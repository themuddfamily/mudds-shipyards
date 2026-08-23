class_name NetworkSnapshotFragmenter
extends RefCounted

## Conservative bounded fragmentation envelope for authoritative snapshots.
## Only a fully reassembled envelope is handed to the delta codec.

const MAX_FRAGMENT_BYTES := 900
const MAX_FRAGMENTS := 16
const MAX_PACKET_BYTES := 12_000
const REASSEMBLY_TIMEOUT_MILLISECONDS := 3000

var _assemblies: Dictionary = {}
var _last_completed_revision := 0


func fragment(packet: Dictionary, generation: int, revision: int) -> Array:
	var encoded := Marshalls.variant_to_base64(packet)
	var bytes := encoded.to_utf8_buffer()
	if generation <= 0 or revision <= 0 or bytes.size() > MAX_PACKET_BYTES:
		return []
	var count := ceili(float(encoded.length()) / float(MAX_FRAGMENT_BYTES))
	if count <= 0 or count > MAX_FRAGMENTS:
		return []
	var fragments: Array = []
	for index in count:
		var start := index * MAX_FRAGMENT_BYTES
		var payload := encoded.substr(start, MAX_FRAGMENT_BYTES)
		fragments.append({
			"generation": generation,
			"revision": revision,
			"index": index,
			"count": count,
			"payload": payload,
		})
	return fragments


func accept(fragment: Dictionary, now_milliseconds: int = 0) -> Dictionary:
	cleanup(now_milliseconds)
	for key in ["generation", "revision", "index", "count", "payload"]:
		if not fragment.has(key):
			return {"accepted": false, "status": &"invalid_fragment"}
	var generation := int(fragment.get("generation", 0))
	var revision := int(fragment.get("revision", 0))
	var index := int(fragment.get("index", -1))
	var count := int(fragment.get("count", 0))
	var payload := String(fragment.get("payload", ""))
	if generation <= 0 or revision <= _last_completed_revision or count <= 0 or count > MAX_FRAGMENTS \
		or index < 0 or index >= count or payload.is_empty() or payload.to_utf8_buffer().size() > MAX_FRAGMENT_BYTES:
		return {"accepted": false, "status": &"stale_or_invalid_fragment"}
	var key := "%d:%d" % [generation, revision]
	if not _assemblies.has(key):
		_assemblies[key] = {"generation": generation, "revision": revision, "count": count, "parts": {}, "started": now_milliseconds}
	var assembly: Dictionary = _assemblies[key]
	if int(assembly.count) != count or assembly.parts.has(index):
		return {"accepted": false, "status": &"duplicate_or_mismatched_fragment"}
	assembly.parts[index] = payload
	if assembly.parts.size() < count:
		return {"accepted": true, "status": &"fragment_buffered", "received": assembly.parts.size(), "count": count}
	var encoded := ""
	for part_index in count:
		if not assembly.parts.has(part_index):
			return {"accepted": false, "status": &"fragment_gap"}
		encoded += String(assembly.parts[part_index])
	_assemblies.erase(key)
	var parsed: Variant = Marshalls.base64_to_variant(encoded)
	if not parsed is Dictionary:
		return {"accepted": false, "status": &"invalid_reassembled_packet"}
	_last_completed_revision = revision
	return {"accepted": true, "status": &"reassembled", "packet": parsed as Dictionary}


func cleanup(now_milliseconds: int) -> void:
	if now_milliseconds <= 0:
		return
	for key in _assemblies.keys():
		if now_milliseconds - int((_assemblies[key] as Dictionary).get("started", now_milliseconds)) > REASSEMBLY_TIMEOUT_MILLISECONDS:
			_assemblies.erase(key)


func reset() -> void:
	_assemblies.clear()
	_last_completed_revision = 0
