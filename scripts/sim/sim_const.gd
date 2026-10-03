class_name SimConst
extends RefCounted
## Simulation constants. All gameplay timing runs on a fixed 60 Hz tick and every
## duration is stored as an integer number of ticks.

const TICK_RATE := 60

## Movement collision radius of every hero body, in arena pixels.
const BODY_RADIUS := 28.0
## Radius used for all hit tests. Slightly smaller than the body so near misses read as dodges.
const HURT_RADIUS := 24.0
## Extra reach granted to melee normal attacks.
const MELEE_TOLERANCE_PX := 12.0

## Global cooldown between skills. It starts when a skill fires (at the end of its cast time).
const GCD_TICKS := 18
## A press is buffered when it would become legal within this many ticks.
const BUFFER_TICKS := 18

const PRE_ROUND_TICKS := 150
## Every skill starts each round on this cooldown. It is visible during the countdown.
const ROUND_START_SKILL_CD_TICKS := 90
const ROUND_TICKS := 3600
const OVERTIME_START_TICK := 2400
## How long the result banner stays up between rounds.
const ROUND_OVER_TICKS := 150
## Damage multiplier once a round reaches overtime, so no round can stall.
const OVERTIME_DAMAGE_MULT := 1.5
## An interrupted cast goes on this cooldown instead of being refunded.
const INTERRUPT_CD_TICKS := 120
const ROUNDS_TO_WIN := 2
## A round that times out with HP percentages this close is a draw.
const DRAW_HP_RATIO_EPSILON := 0.01
const MAX_DRAW_REPLAYS := 1

## Move vectors shorter than this are treated as idle.
const MOVE_DEADZONE := 0.1
## Walking speed never drops below this fraction of base speed while slowed.
const MIN_SPEED_FACTOR := 0.6


static func to_ticks(seconds: float) -> int:
	return roundi(seconds * TICK_RATE)
