class_name LocalPlayerController
extends HeroController
## Merges the touch HUD (fed through signals) and the keyboard into HeroCommands for the
## local player. Taps and skill releases are latched until the next tick consumes them,
## so a fast tap between two physics ticks is never lost.

const SKILL_ACTIONS := [&"skill_1", &"skill_2", &"skill_3"]
const CURSOR_SKILL_ACTIONS := [&"skill_at_cursor_1", &"skill_at_cursor_2", &"skill_at_cursor_3"]

## Returns the mouse position in arena coordinates. Set by the arena scene.
var cursor_to_arena: Callable

var _touch_move := Vector2.ZERO
var _touch_attack := false
var _tap_attack := false
var _pending_skill := -1
var _pending_pad := Vector2.ZERO
var _pending_manual := false


func set_touch_move(v: Vector2) -> void:
	_touch_move = v


func set_touch_attack(held: bool) -> void:
	_touch_attack = held


func tap_attack() -> void:
	_tap_attack = true


## Called when a skill button is released. pad is the drag-aim vector (length 0..1).
func queue_skill(slot: int, pad: Vector2, manual: bool) -> void:
	_pending_skill = slot
	_pending_pad = pad
	_pending_manual = manual


func reset() -> void:
	_touch_move = Vector2.ZERO
	_touch_attack = false
	_tap_attack = false
	_pending_skill = -1
	_pending_pad = Vector2.ZERO
	_pending_manual = false


func build_command(tick: int, state: MatchState) -> HeroCommand:
	var cmd := HeroCommand.idle(tick)
	var me := state.heroes[hero_index]

	var kb := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	cmd.move = kb if kb.length() > _touch_move.length() else _touch_move

	cmd.attack_held = _touch_attack or Input.is_action_pressed(&"attack")
	cmd.attack_pressed = _tap_attack or Input.is_action_just_pressed(&"attack")

	var skill_count := me.data.skills.size()
	if _pending_skill >= 0 and _pending_skill < skill_count:
		cmd.skill_index = _pending_skill
		if _pending_manual:
			cmd.manual_aim = true
			cmd.aim = _pad_to_aim(me.data.skills[_pending_skill], _pending_pad)
	else:
		for i in mini(skill_count, SKILL_ACTIONS.size()):
			if Input.is_action_just_pressed(SKILL_ACTIONS[i]):
				cmd.skill_index = i
				break
			if Input.is_action_just_pressed(CURSOR_SKILL_ACTIONS[i]) and cursor_to_arena.is_valid():
				var cursor: Vector2 = cursor_to_arena.call()
				cmd.skill_index = i
				cmd.manual_aim = true
				cmd.aim = _clamp_aim(me.data.skills[i], cursor - me.pos)
				break

	_tap_attack = false
	_pending_skill = -1
	_pending_manual = false
	return cmd


## Converts a drag-aim pad vector (length 0..1) into an aim offset in arena pixels.
static func _pad_to_aim(skill: SkillData, pad: Vector2) -> Vector2:
	if skill.targeting == SkillData.Targeting.POINT:
		return pad.limit_length(1.0) * skill.range_px
	if skill.targeting == SkillData.Targeting.DIRECTION and pad.length_squared() > 0.0001:
		return pad.normalized() * skill.range_px
	return Vector2.ZERO


static func _clamp_aim(skill: SkillData, offset: Vector2) -> Vector2:
	if skill.targeting == SkillData.Targeting.DIRECTION:
		if offset.length_squared() <= 0.0001:
			return Vector2.ZERO
		return offset.normalized() * skill.range_px
	if skill.targeting == SkillData.Targeting.POINT:
		return offset.limit_length(skill.range_px)
	return Vector2.ZERO
