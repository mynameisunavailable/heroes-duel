class_name SkillData
extends Resource
## One hero skill: timing, targeting and the effects it applies. Pure data; numbers are
## entered in seconds and pixels and converted to ticks by the simulation.

enum Targeting { DIRECTION, POINT, AROUND_SELF }
enum QuickAim { AT_ENEMY, AWAY_OR_JOYSTICK, SELF }

@export var id: String = ""
@export var display_name: String = ""
## Two-letter label used on placeholder buttons.
@export var abbrev: String = ""
@export_multiline var description: String = ""
## Optional button icon; a coloured disc with the abbreviation is drawn when empty.
@export var icon: Texture2D

@export_group("Timing")
@export_range(0.0, 60.0, 0.05, "suffix:s") var cooldown_s: float = 8.0
@export_range(0.0, 3.0, 0.05, "suffix:s") var cast_time_s: float = 0.0

@export_group("Targeting")
@export var targeting: Targeting = Targeting.DIRECTION
## How a tap (quick cast) aims this skill.
@export var quick_aim: QuickAim = QuickAim.AT_ENEMY
@export_range(0.0, 2000.0, 1.0, "suffix:px") var range_px: float = 0.0
@export_range(0.0, 1000.0, 1.0, "suffix:px") var radius_or_width_px: float = 0.0
@export var telegraph_color := Color(1, 1, 1, 0.5)

@export_group("Effects")
@export var effects: Array[EffectData] = []


func cooldown_ticks() -> int:
	return SimConst.to_ticks(cooldown_s)


func cast_ticks() -> int:
	return SimConst.to_ticks(cast_time_s)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("missing id")
	if cooldown_s <= 0.0:
		errors.append("cooldown_s must be > 0")
	if effects.is_empty():
		errors.append("no effects")
	for effect in effects:
		if effect == null:
			errors.append("null effect")
		elif effect is ProjectileEffect and not is_equal_approx((effect as ProjectileEffect).max_range_px, range_px):
			errors.append("projectile max_range_px differs from range_px")
		elif effect is DashEffect and not is_equal_approx((effect as DashEffect).distance_px, range_px):
			errors.append("dash distance_px differs from range_px")
	return errors
