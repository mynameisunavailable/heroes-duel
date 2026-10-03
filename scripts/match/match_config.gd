class_name MatchConfig
extends RefCounted
## Everything needed to start a match. Built by Game defaults now, by menus later.

enum ControllerKind { LOCAL, AI, NETWORK }

var hero_ids := PackedStringArray(["knight", "ranger"])
var controller_kinds := PackedInt32Array([ControllerKind.LOCAL, ControllerKind.AI])
var ai_difficulty: int = AIController.Difficulty.NORMAL
var arena_path := "res://data/arenas/duel_arena.tres"
var rng_seed: int = 12345
var rounds_to_win: int = 2


static func default_vs_ai() -> MatchConfig:
	return MatchConfig.new()
