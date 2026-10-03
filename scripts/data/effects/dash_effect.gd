class_name DashEffect
extends EffectData
## Moves the caster along the aim direction. STOP_ON_HIT applies the payload to the first
## enemy touched and stops there; PASS_THROUGH applies it once to each enemy crossed;
## NONE is pure movement.

enum Mode { STOP_ON_HIT, PASS_THROUGH, NONE }

@export_range(0.0, 1000.0, 1.0, "suffix:px") var distance_px: float = 0.0
@export_range(0.0, 3000.0, 10.0, "suffix:px/s") var speed_px_s: float = 1000.0
@export_range(0.0, 200.0, 1.0, "suffix:px") var width_px: float = 56.0
@export var mode: Mode = Mode.NONE
@export var payload: Array[EffectData] = []


func describe() -> String:
	return "Dash %d px" % roundi(distance_px)
