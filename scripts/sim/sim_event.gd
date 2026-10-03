class_name SimEvent
extends RefCounted
## A gameplay event produced by the simulation. Presentation (HUD, effects, audio,
## haptics) reacts to these instead of reading player input, so it can never change
## the outcome and can be replayed or sent over the network.

enum Kind {
	ROUND_PHASE,
	ATTACK_STARTED,
	ATTACK_DENIED_RANGE,
	SKILL_CAST_STARTED,
	SKILL_FIRED,
	SKILL_DENIED,
	SKILL_BUFFERED,
	DAMAGE,
	STATUS_APPLIED,
	KO,
	ROUND_ENDED,
	MATCH_ENDED,
}

var kind: Kind = Kind.ROUND_PHASE
var tick: int = 0
var source: int = -1
var target: int = -1
var slot: int = -1
var amount: int = 0
var pos := Vector2.ZERO


static func create(p_kind: Kind, p_tick: int, p_source: int = -1, p_target: int = -1, p_slot: int = -1, p_amount: int = 0) -> SimEvent:
	var ev := SimEvent.new()
	ev.kind = p_kind
	ev.tick = p_tick
	ev.source = p_source
	ev.target = p_target
	ev.slot = p_slot
	ev.amount = p_amount
	return ev
