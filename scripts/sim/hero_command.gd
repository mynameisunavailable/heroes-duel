class_name HeroCommand
extends RefCounted
## One hero's input for one simulation tick. Every controller (touch, keyboard, AI and,
## later, the network) produces these, so the simulation never knows where input came from.

var tick: int = 0
var seq: int = 0
## Desired move direction, length 0..1.
var move := Vector2.ZERO
var attack_held := false
## Latched single tap of the attack button.
var attack_pressed := false
## Skill slot pressed this tick, or -1.
var skill_index: int = -1
## Aim offset from the caster in arena pixels. Only used when manual_aim is true.
var aim := Vector2.ZERO
var manual_aim := false


static func idle(p_tick: int) -> HeroCommand:
	var cmd := HeroCommand.new()
	cmd.tick = p_tick
	return cmd


## Quantises analog values the way the network codec will (8-bit move axes, whole-pixel
## aim), so offline play, the server and client prediction all simulate identical input.
func quantize() -> void:
	move = Vector2(_quantize_axis(move.x), _quantize_axis(move.y))
	aim = aim.round()


static func _quantize_axis(value: float) -> float:
	return roundf(clampf(value, -1.0, 1.0) * 127.0) / 127.0
