extends Node2D
## Composition root of a match: builds the simulation, controllers, views and HUD, wires
## them together, lays the arena out for the current screen shape and handles pausing.

const HERO_VIEW := preload("res://scenes/hero/hero_view.tscn")
## Height of the top HUD band (HP bars, timer, pause button) in viewport units.
const TOP_BAND := 80.0
const MARGIN := 6.0

var _local: LocalPlayerController
var _arena: ArenaData

@onready var runner: MatchRunner = $MatchRunner
@onready var world: Node2D = $World
@onready var arena_view: ArenaView = $World/ArenaView
@onready var heroes_root: Node2D = $World/Heroes
@onready var fx: FxView = $World/Fx
@onready var damage_numbers: DamageNumbers = $World/DamageNumbers
@onready var hud: Hud = $Hud


func _ready() -> void:
	var config: MatchConfig = Game.next_match
	_arena = load(config.arena_path) as ArenaData
	if _arena == null or Game.roster == null:
		push_error("Arena or hero roster failed to load.")
		return
	var hero_data: Array[HeroData] = []
	for hero_id in config.hero_ids:
		var data := Game.roster.find(hero_id)
		if data == null:
			push_error("Unknown hero id in match config: %s" % hero_id)
			return
		hero_data.append(data)

	var sim := CombatSim.new(_arena, hero_data, config.rng_seed)
	var controllers: Array[HeroController] = []
	for i in hero_data.size():
		controllers.append(_make_controller(config, i, hero_data[i], sim.geometry))
	runner.setup(sim, controllers)

	arena_view.setup(_arena)
	var mirror := hero_data[0] == hero_data[1]
	for hero in sim.state.heroes:
		var view := HERO_VIEW.instantiate() as HeroView
		heroes_root.add_child(view)
		view.setup(hero, Palette.TEAM[hero.index], mirror and hero.index == 1, hero.index != 0)

	fx.setup(sim.state, sim.geometry, 0)
	hud.setup(sim.state, 0)
	if _local != null:
		hud.move_input_changed.connect(_local.set_touch_move)
		hud.attack_held_changed.connect(_local.set_touch_attack)
		hud.attack_tapped.connect(_local.tap_attack)
		hud.skill_released.connect(_local.queue_skill)
	hud.aim_preview_changed.connect(fx.set_aim_preview)
	hud.pause_requested.connect(_set_paused.bind(true))
	hud.resume_requested.connect(_set_paused.bind(false))
	hud.restart_requested.connect(_restart)
	runner.sim_event.connect(hud.on_sim_event)
	runner.sim_event.connect(damage_numbers.on_sim_event)

	get_viewport().size_changed.connect(_layout)
	_layout()
	runner.running = true


func _make_controller(config: MatchConfig, index: int, data: HeroData, geometry: ArenaGeometry) -> HeroController:
	if config.controller_kinds[index] == MatchConfig.ControllerKind.LOCAL and _local == null:
		_local = LocalPlayerController.new()
		_local.cursor_to_arena = func() -> Vector2: return world.get_local_mouse_position()
		return _local
	return AIController.new(data.ai_profile, config.ai_difficulty, config.rng_seed + index, geometry)


## Fits the arena under the top HUD band and inside the safe area, then anchors it to
## the top so the bottom corners (under the thumbs) stay as clear as possible. The world
## is only scaled, never re-measured, so gameplay numbers are identical on every device.
func _layout() -> void:
	if _arena == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var m := AppEnv.safe_margins(get_viewport())
	var play := Rect2(
		Vector2(m.x + MARGIN, m.y + TOP_BAND),
		Vector2(vp.x - m.x - m.z - MARGIN * 2.0, vp.y - m.y - m.w - TOP_BAND - MARGIN))
	var s := minf(1.0, minf(play.size.x / _arena.size.x, play.size.y / _arena.size.y))
	world.scale = Vector2(s, s)
	world.position = Vector2(
		floorf(play.position.x + (play.size.x - _arena.size.x * s) * 0.5),
		floorf(play.position.y))


func _set_paused(paused: bool) -> void:
	runner.running = not paused
	if paused and _local != null:
		_local.reset()
	hud.show_paused(paused)


func _restart() -> void:
	get_tree().reload_current_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and runner.sim != null:
		_set_paused(runner.running)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Pause vs-AI play when the app is backgrounded or covered by a system overlay.
	var interrupted := what == NOTIFICATION_APPLICATION_PAUSED \
		or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and AppEnv.is_mobile())
	if interrupted and runner != null and runner.running:
		_set_paused(true)
