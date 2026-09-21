class_name AuroraTemperateStreamingProductionBinding
extends PlanetaryStreamingProductionBinding

## Production caller-physics adapter for [AuroraTemperateStreamingBootstrap].
##
## It is deliberately the same thirty lines Ember's binding is: the observation
## cadence, the origin-rebase preview and the committed-rebase reconciliation
## all live in [PlanetaryStreamingProductionBinding] and are shared, so the one
## [CommonWorldOriginRebaseOwner] can rebase whichever of the two worlds the
## player is travelling to.

const DEFAULT_BOOTSTRAP_PATH := NodePath("../AuroraTemperateStreamingBootstrap")


func _default_bootstrap_path() -> NodePath:
	return DEFAULT_BOOTSTRAP_PATH


func _world_label() -> String:
	return "Aurora"


func _expected_world_id() -> StringName:
	return AuroraTemperateStreamingBootstrap.WORLD_ID


func _bootstrap_is_expected(bootstrap: PlanetaryStreamingBootstrap) -> bool:
	return bootstrap is AuroraTemperateStreamingBootstrap
