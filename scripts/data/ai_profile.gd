class_name AIProfile
extends Resource
## How the AI moves with a hero: chase into melee, kite inside a distance band, or rush
## along a curve so straight skillshots miss.

enum MoveStyle { CHASE, KITE, RUSH_CURVE }

@export var move_style: MoveStyle = MoveStyle.CHASE
@export_range(0.0, 1000.0, 1.0, "suffix:px") var preferred_min_px: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var preferred_max_px: float = 90.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var retreat_below_px: float = 0.0
@export_range(0.1, 10.0, 0.1, "suffix:s") var strafe_switch_min_s: float = 1.5
@export_range(0.1, 10.0, 0.1, "suffix:s") var strafe_switch_max_s: float = 2.5
