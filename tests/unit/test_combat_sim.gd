extends GutTest
## CombatSim rules that are easy to break and expensive to notice: simultaneous
## resolution, cast lock, the global cooldown, input buffering and determinism.

const ROSTER_PATH := "res://data/roster.tres"
const ARENA_PATH := "res://data/arenas/duel_arena.tres"
const CLEAVE_SLOT := 1

var _roster: HeroRoster
var _arena: ArenaData


func before_each() -> void:
	_roster = load(ROSTER_PATH) as HeroRoster
	_arena = load(ARENA_PATH) as ArenaData


# --- helpers --------------------------------------------------------------------

func _make_sim(a_id: String, b_id: String, rng_seed: int = 7) -> CombatSim:
	var heroes: Array[HeroData] = [_roster.find(a_id), _roster.find(b_id)]
	return CombatSim.new(_arena, heroes, rng_seed)


func _cmd(tick: int, move := Vector2.ZERO, attack := false, skill := -1) -> HeroCommand:
	var c := HeroCommand.idle(tick)
	c.move = move
	c.attack_held = attack
	c.skill_index = skill
	return c


func _step(sim: CombatSim, a: HeroCommand = null, b: HeroCommand = null) -> void:
	var tick := sim.state.tick + 1
	var cmds: Array[HeroCommand] = [
		a if a != null else HeroCommand.idle(tick),
		b if b != null else HeroCommand.idle(tick),
	]
	sim.step(cmds)


## Steps past the countdown and the round-start skill lock, so skills can be cast.
func _skip_to_ready(sim: CombatSim) -> void:
	for _i in SimConst.PRE_ROUND_TICKS + SimConst.ROUND_START_SKILL_CD_TICKS + 1:
		_step(sim)


func _events_of(sim: CombatSim, kind: SimEvent.Kind) -> Array[SimEvent]:
	var found: Array[SimEvent] = []
	for ev in sim.state.events:
		if ev.kind == kind:
			found.append(ev)
	return found


# --- simultaneous resolution ----------------------------------------------------

func test_a_mirror_match_stays_perfectly_symmetric() -> void:
	# Resolving one hero fully before the other gives whoever goes second about a tick of
	# extra reach, which silently decides every mirror match. Two identical knights must
	# stay mirror images of each other for the whole round.
	var sim := _make_sim("knight", "knight")
	var a := AIController.new(_roster.find("knight").ai_profile, AIController.Difficulty.NORMAL, 1, sim.geometry)
	var b := AIController.new(_roster.find("knight").ai_profile, AIController.Difficulty.NORMAL, 2, sim.geometry)
	a.hero_index = 0
	b.hero_index = 1
	var mid: float = _arena.size.x * 0.5

	for _i in 1500:
		var tick := sim.state.tick + 1
		var cmds: Array[HeroCommand] = [a.build_command(tick, sim.state), b.build_command(tick, sim.state)]
		for c in cmds:
			c.quantize()
		sim.step(cmds)
		var h0 := sim.state.heroes[0]
		var h1 := sim.state.heroes[1]
		assert_almost_eq(mid - h0.pos.x, h1.pos.x - mid, 0.001, "x mirrored at tick %d" % sim.state.tick)
		assert_almost_eq(h0.pos.y, h1.pos.y, 0.001, "y equal at tick %d" % sim.state.tick)
		assert_eq(h0.hp, h1.hp, "hp equal at tick %d" % sim.state.tick)
		if sim.state.round_result != MatchState.RESULT_NONE:
			break
	assert_eq(sim.state.round_result, MatchState.RESULT_DRAW, "a true mirror round must be a draw")


func test_simultaneous_lethal_blows_kill_both_heroes() -> void:
	# The first lethal hit must not cancel the one coming back, or the double-KO draw
	# rule can never trigger.
	var sim := _make_sim("knight", "knight")
	_skip_to_ready(sim)
	var h0 := sim.state.heroes[0]
	var h1 := sim.state.heroes[1]
	h0.hp = 5
	h1.hp = 5
	h0.pos = Vector2(470.0, 240.0)
	h1.pos = Vector2(530.0, 240.0)

	var ended := false
	for _i in 120:
		_step(sim, _cmd(sim.state.tick + 1, Vector2.ZERO, true), _cmd(sim.state.tick + 1, Vector2.ZERO, true))
		if sim.state.phase != MatchState.Phase.FIGHT:
			ended = true
			break
	assert_true(ended, "the round should have ended")
	assert_false(h0.alive, "hero 0 died")
	assert_false(h1.alive, "hero 1 died")
	assert_eq(sim.state.round_result, MatchState.RESULT_DRAW)


# --- cast lock and the global cooldown -------------------------------------------

func test_casting_roots_the_hero() -> void:
	var sim := _make_sim("knight", "ranger")
	_skip_to_ready(sim)
	var knight := sim.state.heroes[0]
	_step(sim, _cmd(sim.state.tick + 1, Vector2.ZERO, false, CLEAVE_SLOT))
	assert_true(knight.is_casting(), "Cleave should be winding up")

	var start := knight.pos
	for _i in 5:
		_step(sim, _cmd(sim.state.tick + 1, Vector2.RIGHT))
		assert_true(knight.is_casting(), "still casting")
		assert_almost_eq(knight.pos.distance_to(start), 0.0, 0.001, "must not walk while casting")


func test_the_global_cooldown_starts_when_the_skill_fires() -> void:
	var sim := _make_sim("knight", "ranger")
	_skip_to_ready(sim)
	var knight := sim.state.heroes[0]
	var cast_ticks := knight.data.skills[CLEAVE_SLOT].cast_ticks()
	assert_gt(cast_ticks, 0, "Cleave has a wind-up, so this test is meaningful")

	_step(sim, _cmd(sim.state.tick + 1, Vector2.ZERO, false, CLEAVE_SLOT))
	assert_eq(knight.gcd_ticks, 0, "no global cooldown during the wind-up")
	for _i in cast_ticks:
		_step(sim)
	assert_false(knight.is_casting(), "the cast finished")
	# The counter is set as the skill fires and ticked down later in that same tick, so
	# one tick of it has already been spent by the time the tick ends.
	assert_eq(knight.gcd_ticks, SimConst.GCD_TICKS - 1, "the global cooldown starts at the moment it fires")
	for _i in SimConst.GCD_TICKS - 1:
		_step(sim)
	assert_eq(knight.gcd_ticks, 0, "and lasts exactly GCD_TICKS from the firing tick")


func test_firing_a_skill_starts_its_own_cooldown() -> void:
	var sim := _make_sim("knight", "ranger")
	_skip_to_ready(sim)
	var knight := sim.state.heroes[0]
	assert_true(knight.skill_cds.is_ready(CLEAVE_SLOT))
	_step(sim, _cmd(sim.state.tick + 1, Vector2.ZERO, false, CLEAVE_SLOT))
	for _i in knight.data.skills[CLEAVE_SLOT].cast_ticks():
		_step(sim)
	assert_almost_eq(float(knight.skill_cds.remaining(CLEAVE_SLOT)),
		float(knight.data.skills[CLEAVE_SLOT].cooldown_ticks()), 2.0)


# --- input buffering --------------------------------------------------------------

func test_a_press_just_before_ready_is_buffered_and_then_fires() -> void:
	var sim := _make_sim("knight", "ranger")
	_skip_to_ready(sim)
	var knight := sim.state.heroes[0]
	knight.skill_cds.start(CLEAVE_SLOT, 10)

	_step(sim, _cmd(sim.state.tick + 1, Vector2.ZERO, false, CLEAVE_SLOT))
	assert_eq(_events_of(sim, SimEvent.Kind.SKILL_BUFFERED).size(), 1, "the press was buffered")
	assert_eq(knight.buffered_slot, CLEAVE_SLOT)

	var fired := false
	for _i in 20:
		_step(sim)
		if not _events_of(sim, SimEvent.Kind.SKILL_CAST_STARTED).is_empty():
			fired = true
			break
	assert_true(fired, "the buffered press should start the cast once the cooldown ends")


func test_a_press_far_from_ready_is_denied_not_buffered() -> void:
	var sim := _make_sim("knight", "ranger")
	_skip_to_ready(sim)
	sim.state.heroes[0].skill_cds.start(CLEAVE_SLOT, 300)

	_step(sim, _cmd(sim.state.tick + 1, Vector2.ZERO, false, CLEAVE_SLOT))
	assert_eq(_events_of(sim, SimEvent.Kind.SKILL_DENIED).size(), 1, "denied")
	assert_eq(sim.state.heroes[0].buffered_slot, -1, "nothing queued")


# --- status rules ------------------------------------------------------------------

func test_a_stronger_slow_replaces_a_weaker_one_but_not_the_reverse() -> void:
	var sim := _make_sim("knight", "ranger")
	_skip_to_ready(sim)
	var target := sim.state.heroes[1]

	StatusRules.apply_slow(sim, target, 0.3, 1.5)
	assert_almost_eq(target.slow_pct, 0.3, 0.001)
	StatusRules.apply_slow(sim, target, 0.4, 2.0)
	assert_almost_eq(target.slow_pct, 0.4, 0.001, "the stronger slow wins")
	StatusRules.apply_slow(sim, target, 0.1, 5.0)
	assert_almost_eq(target.slow_pct, 0.4, 0.001, "a weaker slow must not override it")


func test_walking_speed_never_drops_below_the_floor() -> void:
	var sim := _make_sim("knight", "ranger")
	_skip_to_ready(sim)
	var target := sim.state.heroes[1]
	target.slow_pct = 0.9
	target.slow_ticks = 60
	assert_almost_eq(target.speed_multiplier(), SimConst.MIN_SPEED_FACTOR, 0.001)


func test_a_stun_interrupts_a_cast_and_puts_it_on_cooldown() -> void:
	var sim := _make_sim("knight", "ranger")
	_skip_to_ready(sim)
	var knight := sim.state.heroes[0]
	_step(sim, _cmd(sim.state.tick + 1, Vector2.ZERO, false, CLEAVE_SLOT))
	assert_true(knight.is_casting())

	StatusRules.apply_stun(sim, knight, 0.5)
	assert_false(knight.is_casting(), "the cast was interrupted")
	assert_eq(knight.skill_cds.remaining(CLEAVE_SLOT), SimConst.INTERRUPT_CD_TICKS,
		"an interrupted cast is not refunded for free")


# --- damage ------------------------------------------------------------------------

func test_overtime_multiplies_damage() -> void:
	var sim := _make_sim("knight", "ranger")
	_skip_to_ready(sim)
	sim.state.round_tick = SimConst.OVERTIME_START_TICK
	assert_true(sim.state.is_overtime())

	var target := sim.state.heroes[1]
	var before := target.hp
	DamageResolver.apply(sim, sim.state.heroes[0], target, 100, target.pos)
	assert_eq(before - target.hp, roundi(100 * SimConst.OVERTIME_DAMAGE_MULT))


func test_damage_never_pushes_hp_below_zero() -> void:
	var sim := _make_sim("knight", "ranger")
	_skip_to_ready(sim)
	var target := sim.state.heroes[1]
	DamageResolver.apply(sim, sim.state.heroes[0], target, 999999, target.pos)
	assert_eq(target.hp, 0)
	assert_false(target.alive)


# --- determinism --------------------------------------------------------------------

func test_the_same_seed_and_inputs_give_the_same_result() -> void:
	var checksums := []
	for run in 2:
		var sim := _make_sim("knight", "ranger", 99)
		var a := AIController.new(_roster.find("knight").ai_profile, AIController.Difficulty.NORMAL, 1, sim.geometry)
		var b := AIController.new(_roster.find("ranger").ai_profile, AIController.Difficulty.NORMAL, 2, sim.geometry)
		a.hero_index = 0
		b.hero_index = 1
		for _i in 900:
			var tick := sim.state.tick + 1
			var cmds: Array[HeroCommand] = [a.build_command(tick, sim.state), b.build_command(tick, sim.state)]
			for c in cmds:
				c.quantize()
			sim.step(cmds)
		checksums.append(sim.state.checksum())
	assert_eq(checksums[0], checksums[1])


func test_heroes_never_leave_the_arena() -> void:
	var sim := _make_sim("knight", "ranger")
	_skip_to_ready(sim)
	# Drive both heroes hard into a corner.
	for _i in 300:
		var tick := sim.state.tick + 1
		_step(sim, _cmd(tick, Vector2(-1.0, -1.0)), _cmd(tick, Vector2(-1.0, -1.0)))
	for h in sim.state.heroes:
		assert_true(sim.geometry.is_inside(h.pos, SimConst.BODY_RADIUS - 0.1),
			"hero %d at %s should still be inside" % [h.index, h.pos])
