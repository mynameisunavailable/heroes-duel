class_name MatchState
extends RefCounted
## Whole-match simulation state: phase, timers, scores and both heroes.

enum Phase { PRE_ROUND, FIGHT, ROUND_OVER, MATCH_OVER }

## Values for round_result and match_winner beyond a hero index of 0 or 1.
const RESULT_NONE := -1
const RESULT_DRAW := 2

var tick: int = 0
var phase: Phase = Phase.PRE_ROUND
var phase_ticks: int = 0
var round_index: int = 1
var round_tick: int = 0
var round_wins := PackedInt32Array([0, 0])
## Winner of the round that just ended: hero index, RESULT_DRAW or RESULT_NONE.
var round_result: int = RESULT_NONE
var match_winner: int = RESULT_NONE
## A drawn round is replayed rather than scored.
var round_is_replay := false
var draw_replays: int = 0

var heroes: Array[HeroState] = []
var projectiles: Array[ProjectileState] = []
var events: Array[SimEvent] = []

var rng_seed: int = 0
var arena: ArenaData


func enemy_of(i: int) -> HeroState:
	return heroes[1 - i]


func round_seconds_left() -> float:
	return float(maxi(SimConst.ROUND_TICKS - round_tick, 0)) / SimConst.TICK_RATE


func is_overtime() -> bool:
	return phase == Phase.FIGHT and round_tick >= SimConst.OVERTIME_START_TICK


## Hash of the gameplay-relevant state. Tests use it to check that identical inputs
## produce identical results; the network layer will use it to detect desyncs.
func checksum() -> int:
	var values := PackedFloat64Array([
		tick, phase, phase_ticks, round_index, round_tick,
		round_wins[0], round_wins[1], round_result,
	])
	for h in heroes:
		values.append_array(PackedFloat64Array([
			h.pos.x, h.pos.y, h.facing.x, h.facing.y, h.hp, h.damage_dealt,
			h.attack_cd, h.windup_ticks, h.gcd_ticks,
			h.cast_slot, h.cast_ticks_left, h.buffered_slot, h.buffered_ticks,
			h.stun_ticks, h.slow_ticks, h.slow_pct,
			1.0 if h.mover.active else 0.0, h.mover.remaining_px,
		]))
		for s in h.skill_cds.slot_count():
			values.append(h.skill_cds.remaining(s))
	for p in projectiles:
		values.append_array(PackedFloat64Array([p.id, p.pos.x, p.pos.y, p.remaining_px]))
	return hash(values)
