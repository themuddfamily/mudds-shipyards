class_name NetworkSnapshotDeltaCodec
extends RefCounted

## Bounded delta envelope for authoritative snapshots. The lifecycle adapter
## remains the schema/generation authority; this codec only reconstructs a
## detached full packet before lifecycle validation.

const FULL_INTERVAL := 8

var _baseline: Dictionary = {}
var _baseline_revision := 0
var _packets_since_full := 0


func reset() -> Dictionary:
	_baseline.clear()
	_baseline_revision = 0
	_packets_since_full = 0
	return {"accepted": true, "status": &"reset"}


func encode(packet: Dictionary, force_full: bool = false) -> Dictionary:
	var revision := int(packet.get("revision", 0))
	var full := force_full or _baseline.is_empty() or _packets_since_full >= FULL_INTERVAL
	if full:
		_baseline = packet.duplicate(true)
		_baseline_revision = revision
		_packets_since_full = 1
		return {"kind": &"full", "base_revision": 0, "revision": revision, "packet": packet.duplicate(true)}
	var previous_revision := _baseline_revision
	var changes: Dictionary = {}
	for key in packet:
		if key == "revision":
			continue
		if not _baseline.has(key) or _baseline[key] != packet[key]:
			changes[key] = packet[key].duplicate(true) if packet[key] is Dictionary or packet[key] is Array else packet[key]
	_baseline = packet.duplicate(true)
	_baseline_revision = revision
	_packets_since_full += 1
	return {
		"kind": &"delta",
		"base_revision": previous_revision,
		"revision": revision,
		"changes": changes.duplicate(true),
	}


func decode(envelope: Dictionary) -> Dictionary:
	var kind := StringName(envelope.get("kind", &""))
	var revision := int(envelope.get("revision", 0))
	if revision <= 0:
		return {"accepted": false, "status": &"invalid_delta_revision"}
	if kind == &"full":
		var packet: Dictionary = envelope.get("packet", {}) as Dictionary
		if packet.is_empty() or int(packet.get("revision", 0)) != revision:
			return {"accepted": false, "status": &"invalid_full_snapshot"}
		_baseline = packet.duplicate(true)
		_baseline_revision = revision
		_packets_since_full = 1
		return {"accepted": true, "status": &"full_snapshot", "packet": packet.duplicate(true)}
	if kind != &"delta" or _baseline.is_empty():
		return {"accepted": false, "status": &"missing_delta_baseline"}
	if int(envelope.get("base_revision", 0)) != _baseline_revision:
		return {"accepted": false, "status": &"stale_delta_baseline"}
	var merged := _baseline.duplicate(true)
	for key in envelope.get("changes", {}):
		merged[key] = envelope.changes[key].duplicate(true) if envelope.changes[key] is Dictionary or envelope.changes[key] is Array else envelope.changes[key]
	merged["revision"] = revision
	_baseline = merged.duplicate(true)
	_baseline_revision = revision
	_packets_since_full += 1
	return {"accepted": true, "status": &"delta_snapshot", "packet": merged}


func get_snapshot() -> Dictionary:
	return {"baseline_revision": _baseline_revision, "packets_since_full": _packets_since_full, "has_baseline": not _baseline.is_empty()}
