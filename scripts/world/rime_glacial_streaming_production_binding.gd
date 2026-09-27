class_name RimeGlacialStreamingProductionBinding
extends PlanetaryStreamingProductionBinding

## Production caller-physics adapter for [RimeGlacialStreamingBootstrap].
##
## Everything it does is shared in [PlanetaryStreamingProductionBinding]; this
## only names Rime, so the one [CommonWorldOriginRebaseOwner] discovers and
## rebases it beside Ember and Aurora.

const DEFAULT_BOOTSTRAP_PATH := NodePath("../RimeGlacialStreamingBootstrap")


func _default_bootstrap_path() -> NodePath:
	return DEFAULT_BOOTSTRAP_PATH


func _world_label() -> String:
	return "Rime"


func _expected_world_id() -> StringName:
	return RimeGlacialStreamingBootstrap.WORLD_ID


func _bootstrap_is_expected(bootstrap: PlanetaryStreamingBootstrap) -> bool:
	return bootstrap is RimeGlacialStreamingBootstrap
