class_name Hud
extends CanvasLayer
## Touch HUD: floating joystick, attack button, 2-3 skill buttons generated from the local
## hero's data, HP bars, round timer, countdown banner and the pause menu.
## It never calls the simulation: input leaves through signals and state is only read.

signal move_input_changed(vector: Vector2)
signal attack_held_changed(held: bool)
signal attack_tapped
signal skill_released(slot: int, pad: Vector2, manual: bool)
signal aim_preview_changed(slot: int, pad: Vector2, active: bool)
signal pause_requested
signal resume_requested
signal restart_requested

## Skill-button angles around the attack button, in degrees (180 = left, 270 = up).
const SKILL_ANGLES_2 := [195.0, 255.0]
const SKILL_ANGLES_3 := [180.0, 225.0, 270.0]
const SKILL_ARC_RADIUS := 160.0
const SKILL_BUTTON_SIZE := 100.0
const ATTACK_BUTTON_SIZE := 140.0
## Attack-button centre, measured from the bottom-right corner of the safe area.
const ATTACK_CENTRE_INSET := Vector2(150.0, 140.0)
## Cancel disc position, as an angle and radius around the attack button.
const CANCEL_ANGLE_DEG := 255.0
const CANCEL_ARC_RADIUS := 300.0

var _state: MatchState
var _local_index := 0
var _skill_buttons: Array[SkillButton] = []
var _pause_overlay: ColorRect
var _result_overlay: ColorRect
var _result_label: Label
var _cancel_disc: CancelDisc
var _no_pips: Array[bool] = []

@onready var joystick: FloatingJoystick = $JoystickZone
@onready var safe_area: Control = $SafeArea
@onready var p1_bar: HpBar = $SafeArea/P1Bar
@onready var p2_bar: HpBar = $SafeArea/P2Bar
@onready var timer_label: Label = $SafeArea/TimerLabel
@onready var banner_label: Label = $SafeArea/BannerLabel
@onready var pause_button: Button = $SafeArea/PauseButton
@onready var action_cluster: Control = $SafeArea/ActionCluster
@onready var attack_button: AttackButton = $SafeArea/ActionCluster/AttackButton


func setup(state: MatchState, local_index: int) -> void:
	_state = state
	_local_index = local_index
	var me := state.heroes[local_index]
	var foe := state.enemy_of(local_index)
	p1_bar.setup(me.data.display_name, Palette.TEAM[me.index])
	p2_bar.setup(foe.data.display_name, Palette.TEAM[foe.index])
	timer_label.add_theme_font_size_override(&"font_size", 44)
	banner_label.add_theme_font_size_override(&"font_size", 72)
	pause_button.add_theme_font_size_override(&"font_size", 30)
	_build_cancel_disc()
	_build_skill_buttons(me.data.skills)
	_pause_overlay = _build_overlay(tr("PAUSED"), [
		[tr("Resume"), resume_requested.emit], [tr("Restart"), restart_requested.emit]])
	_result_overlay = _build_overlay("", [[tr("Rematch"), restart_requested.emit]])
	_result_label = _result_overlay.get_meta("title") as Label

	joystick.vector_changed.connect(move_input_changed.emit)
	attack_button.held_changed.connect(attack_held_changed.emit)
	attack_button.tapped.connect(attack_tapped.emit)
	pause_button.pressed.connect(pause_requested.emit)

	UserSettings.changed.connect(_on_settings_changed)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func _on_settings_changed(_key: StringName) -> void:
	for button in _skill_buttons:
		button.haptics_enabled = UserSettings.haptics_enabled


func show_paused(paused: bool) -> void:
	_pause_overlay.visible = paused
	pause_button.visible = not paused
	reset_controls()


## Releases every held touch control (pause, app interruption).
func reset_controls() -> void:
	joystick.reset()
	attack_button.reset()
	for button in _skill_buttons:
		button.reset()
	if _cancel_disc != null:
		_cancel_disc.visible = false
		_cancel_disc.hovered = false


func on_sim_event(ev: SimEvent) -> void:
	if ev.kind == SimEvent.Kind.MATCH_ENDED:
		_show_match_result(ev.source)
		return
	if ev.kind == SimEvent.Kind.DAMAGE and ev.target == _local_index:
		Haptics.pulse(Haptics.Kind.MEDIUM, UserSettings.haptics_enabled)
		return
	if ev.source != _local_index:
		return
	if ev.kind == SimEvent.Kind.SKILL_DENIED and ev.slot >= 0 and ev.slot < _skill_buttons.size():
		_skill_buttons[ev.slot].deny()
	elif ev.kind == SimEvent.Kind.ATTACK_DENIED_RANGE:
		attack_button.deny()


func _show_match_result(winner: int) -> void:
	if winner == MatchState.RESULT_DRAW:
		_result_label.text = tr("DRAW")
	elif winner == _local_index:
		_result_label.text = tr("VICTORY")
	else:
		_result_label.text = tr("DEFEAT")
	_result_overlay.visible = true
	pause_button.visible = false
	reset_controls()


func _process(_delta: float) -> void:
	if _state == null:
		return
	var me := _state.heroes[_local_index]
	var foe := _state.enemy_of(_local_index)
	p1_bar.set_values(me.hp_ratio(), _state.round_wins[me.index], _no_pips)
	p2_bar.set_values(foe.hp_ratio(), _state.round_wins[foe.index], _ready_pips(foe))
	timer_label.text = str(ceili(_state.round_seconds_left()))
	timer_label.modulate = Palette.DENIED if _state.is_overtime() else Color.WHITE
	banner_label.text = _banner_text()
	for i in _skill_buttons.size():
		_skill_buttons[i].set_cooldown(
			me.skill_cds.fraction_remaining(i),
			me.skill_cds.remaining(i) / float(SimConst.TICK_RATE))


func _banner_text() -> String:
	match _state.phase:
		MatchState.Phase.PRE_ROUND:
			var t := _state.phase_ticks
			if t < 60:
				return tr("ROUND %d") % _state.round_index
			return str(3 - floori((t - 60) / 30.0))
		MatchState.Phase.FIGHT:
			if _state.round_tick < 30:
				return tr("FIGHT")
			if _state.is_overtime() and _state.round_tick < SimConst.OVERTIME_START_TICK + 60:
				return tr("OVERTIME")
		MatchState.Phase.ROUND_OVER:
			if _state.round_is_replay:
				return tr("DRAW - REPLAY")
			if _state.round_result == MatchState.RESULT_DRAW:
				return tr("DRAW")
			return tr("%s WINS") % _state.heroes[_state.round_result].data.display_name
	return ""


static func _ready_pips(h: HeroState) -> Array[bool]:
	var pips: Array[bool] = []
	for i in h.skill_cds.slot_count():
		pips.append(h.skill_cds.is_ready(i))
	return pips


func _apply_layout() -> void:
	var m := AppEnv.safe_margins(get_viewport())
	_place(safe_area, Vector4(0, 0, 1, 1), Vector4(m.x, m.y, -m.z, -m.w))
	# Touch zones are not inset: thumbs rest right at the screen edge.
	_place(joystick, Vector4(0, 0, 0.45, 1), Vector4(0, 80, 0, 0))
	joystick.idle_centre_offset = Vector2(m.x + 170.0, -(m.w + 160.0))

	_place(p1_bar, Vector4(0, 0, 0, 0), Vector4(16, 8, 436, 56))
	_place(p2_bar, Vector4(1, 0, 1, 0), Vector4(-436, 8, -16, 56))
	_place(timer_label, Vector4(0.5, 0, 0.5, 0), Vector4(-70, 6, 70, 74))
	_place(pause_button, Vector4(0.5, 0, 0.5, 0), Vector4(84, 0, 164, 80))
	_place(banner_label, Vector4(0.5, 0.5, 0.5, 0.5), Vector4(-320, -90, 320, 90))
	_place(action_cluster, Vector4(1, 1, 1, 1), Vector4(
		-ATTACK_CENTRE_INSET.x, -ATTACK_CENTRE_INSET.y, -ATTACK_CENTRE_INSET.x, -ATTACK_CENTRE_INSET.y))
	var half := ATTACK_BUTTON_SIZE * 0.5
	_place(attack_button, Vector4(0, 0, 0, 0), Vector4(-half, -half, half, half))


func _build_skill_buttons(skills: Array[SkillData]) -> void:
	var angles: Array = SKILL_ANGLES_3 if skills.size() >= 3 else SKILL_ANGLES_2
	for i in mini(skills.size(), angles.size()):
		var button := SkillButton.new()
		button.setup(i, skills[i])
		button.haptics_enabled = UserSettings.haptics_enabled
		button.size = Vector2.ONE * SKILL_BUTTON_SIZE
		var angle: float = deg_to_rad(angles[i])
		button.position = Vector2.from_angle(angle) * SKILL_ARC_RADIUS - button.size * 0.5
		button.released.connect(skill_released.emit)
		button.aim_changed.connect(aim_preview_changed.emit)
		button.aim_changed.connect(_on_aim_changed)
		button.cancel_hovered.connect(func(hovered: bool) -> void: _cancel_disc.hovered = hovered)
		action_cluster.add_child(button)
		_skill_buttons.append(button)


func _build_cancel_disc() -> void:
	_cancel_disc = CancelDisc.new()
	_cancel_disc.size = Vector2.ONE * CancelDisc.RADIUS * 2.0
	_cancel_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cancel_disc.visible = false
	action_cluster.add_child(_cancel_disc)
	_cancel_disc.position = Vector2.from_angle(deg_to_rad(CANCEL_ANGLE_DEG)) * CANCEL_ARC_RADIUS - _cancel_disc.size * 0.5


## Shows the cancel disc only while a skill is actually being aimed, and tells the skill
## buttons where it ended up so they can test a release against it.
func _on_aim_changed(_slot: int, _pad: Vector2, active: bool) -> void:
	if active == _cancel_disc.visible:
		return
	_cancel_disc.visible = active
	if not active:
		_cancel_disc.hovered = false
	var centre := _cancel_disc.centre_global()
	for button in _skill_buttons:
		button.cancel_centre = centre
		button.cancel_radius = CancelDisc.RADIUS if active else 0.0


## A full-screen dark overlay with a title and a column of buttons. The title Label is
## stored as metadata so callers can change its text later.
func _build_overlay(title_text: String, buttons: Array) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)
	_place(overlay, Vector4(0, 0, 1, 1), Vector4.ZERO)

	var centre := CenterContainer.new()
	overlay.add_child(centre)
	_place(centre, Vector4(0, 0, 1, 1), Vector4.ZERO)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 16)
	centre.add_child(box)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 56)
	box.add_child(title)
	overlay.set_meta("title", title)
	for entry in buttons:
		box.add_child(_menu_button(entry[0] as String, entry[1] as Callable))
	return overlay


static func _menu_button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(260, 80)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override(&"font_size", 32)
	button.pressed.connect(on_pressed)
	return button


## Anchors as (left, top, right, bottom) fractions of the parent, then pixel offsets from
## those anchors. push_opposite_anchor must stay true: raising the left anchor above the
## right one would otherwise be clamped straight back down.
static func _place(c: Control, anchors: Vector4, offsets: Vector4) -> void:
	c.set_anchor(SIDE_LEFT, anchors.x, false, true)
	c.set_anchor(SIDE_TOP, anchors.y, false, true)
	c.set_anchor(SIDE_RIGHT, anchors.z, false, true)
	c.set_anchor(SIDE_BOTTOM, anchors.w, false, true)
	c.offset_left = offsets.x
	c.offset_top = offsets.y
	c.offset_right = offsets.z
	c.offset_bottom = offsets.w
