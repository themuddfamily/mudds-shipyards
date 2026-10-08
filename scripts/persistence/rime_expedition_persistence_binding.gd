class_name RimeExpeditionPersistenceBinding
extends "res://scripts/persistence/planetary_surface_visit_persistence_binding.gd"

## Namespaced atomic-store bridge for one interrupted Rime visit.
##
## The bridge itself is the shared surface-visit binding. Rime's records keep
## their payload kind and `rime_*` reasons, and every Rime record carries the
## ice-core survey's route progress, so the survey key is required here.

const SurveyType := preload("res://scripts/activities/rime_ice_core_survey.gd")
const PAYLOAD_KIND := "rime_expedition_active_visit"
const VISIT_KEYS := [
	"visit_state",
	"craft_home_berth_id",
	"on_foot",
	"survey",
]


func _init() -> void:
	super("rime", PAYLOAD_KIND, SurveyType, true)


## UserDataStore uses JSON's default numeric precision. Canonicalize heat to
## that representation before the full-precision visit receipt hashes it, so
## fractional physics expenditure survives disk reload with the same receipt.
func normalize_visit(candidate: Variant) -> Dictionary:
	var normalized := super.normalize_visit(candidate)
	if bool(normalized.get("accepted", false)):
		var visit := normalized.get("visit", {}) as Dictionary
		var progress := visit.get("survey", {}) as Dictionary
		if progress.has("heat_s"):
			progress["heat_s"] = float(JSON.parse_string(JSON.stringify(float(progress["heat_s"]))))
	return normalized


static func _digest(visit: Dictionary) -> String:
	return digest_visit(visit)
