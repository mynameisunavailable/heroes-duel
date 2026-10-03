class_name RoundRules
extends RefCounted
## Decides when a round ends and who won it, then whether the match is over.
## Best of 3. A drawn round is replayed once; a second draw is settled on total match
## damage, and if even that is level the match itself is a draw.


## Called at the end of every FIGHT tick. Returns true when the round has just ended.
static func check_round_end(sim: CombatSim) -> bool:
	var state := sim.state
	var a := state.heroes[0]
	var b := state.heroes[1]

	var result := MatchState.RESULT_NONE
	if not a.alive and not b.alive:
		result = MatchState.RESULT_DRAW
	elif not b.alive:
		result = 0
	elif not a.alive:
		result = 1
	elif state.round_tick >= SimConst.ROUND_TICKS:
		result = _decide_on_health(a, b)
	if result == MatchState.RESULT_NONE:
		return false

	state.round_is_replay = false
	if result == MatchState.RESULT_DRAW:
		if state.draw_replays < SimConst.MAX_DRAW_REPLAYS:
			state.draw_replays += 1
			state.round_is_replay = true
		else:
			result = _decide_on_damage(a, b)
	if result != MatchState.RESULT_DRAW:
		state.round_wins[result] += 1

	state.round_result = result
	state.phase = MatchState.Phase.ROUND_OVER
	state.phase_ticks = 0
	var ev := sim.emit_event(SimEvent.Kind.ROUND_ENDED, result)
	if ev != null:
		ev.amount = state.round_index
	return true


## Called once the round-over banner has been up long enough. Starts the next round, or
## ends the match. Returns true when the match is over.
static func advance_after_round(sim: CombatSim) -> bool:
	var state := sim.state
	if state.round_is_replay:
		sim.reset_round()
		return false

	var leader := 0 if state.round_wins[0] >= state.round_wins[1] else 1
	var decided := state.round_wins[leader] >= SimConst.ROUNDS_TO_WIN
	if decided or state.round_result == MatchState.RESULT_DRAW:
		state.match_winner = leader if decided else MatchState.RESULT_DRAW
		state.phase = MatchState.Phase.MATCH_OVER
		state.phase_ticks = 0
		sim.emit_event(SimEvent.Kind.MATCH_ENDED, state.match_winner)
		return true

	state.round_index += 1
	sim.reset_round()
	return false


static func _decide_on_health(a: HeroState, b: HeroState) -> int:
	var gap := a.hp_ratio() - b.hp_ratio()
	if absf(gap) <= SimConst.DRAW_HP_RATIO_EPSILON:
		return MatchState.RESULT_DRAW
	return 0 if gap > 0.0 else 1


static func _decide_on_damage(a: HeroState, b: HeroState) -> int:
	if a.damage_dealt == b.damage_dealt:
		return MatchState.RESULT_DRAW
	return 0 if a.damage_dealt > b.damage_dealt else 1
