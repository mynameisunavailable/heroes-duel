class_name AreaOverTimeEffect
extends EffectData
## A ground circle that applies its payload on a timer: one tick after a delay is a
## delayed blast, many ticks is a lingering zone. Ignores pillars and line of sight.
##
## Data-only for now. The simulation gains AreaState in v1.1, alongside the Pyromancer
## (Meteor) and the Rogue (Poison Cloud); SkillExecutor warns if a skill uses it today.

@export_range(0.0, 500.0, 1.0, "suffix:px") var radius_px: float = 100.0
## Telegraph time before the first tick lands.
@export_range(0.0, 5.0, 0.05, "suffix:s") var delay_s: float = 1.0
@export_range(1, 20, 1) var ticks: int = 1
@export_range(0.05, 5.0, 0.05, "suffix:s") var tick_interval_s: float = 0.5
@export var payload: Array[EffectData] = []

@export_group("Look")
@export var color := Color(1.0, 0.5, 0.0, 0.35)
@export var sprite: Texture2D


func describe() -> String:
	return "Area %d px, %d tick(s)" % [roundi(radius_px), ticks]
