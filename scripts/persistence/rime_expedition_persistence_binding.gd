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


static func _digest(visit: Dictionary) -> String:
	return digest_visit(visit)
