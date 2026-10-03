extends SceneTree
## Headless balance batch: plays AI-vs-AI matches across many seeds and reports win
## rates, round lengths and damage. Use it to check a tuning change rather than guessing.
## Run: godot --headless --path . -s res://tools/ai_batch.gd -- --matches=20

const MAX_TICKS := 40000

var _matches := 20


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--matches="):
			_matches = maxi(arg.trim_prefix("--matches=").to_int(), 1)

	var roster := load("res://data/roster.tres") as HeroRoster
	var arena := load("res://data/arenas/duel_arena.tres") as ArenaData
	if roster == null or arena == null:
		printerr("could not load roster or arena")
		quit(1)
		return

	var ids := roster.ids()
	print("Heroes Duel balance batch: %d matches per pairing\n" % _matches)
	for i in ids.size():
		for j in range(i, ids.size()):
			_report(roster.find(ids[i]), roster.find(ids[j]), arena)
	quit(0)


func _report(a: HeroData, b: HeroData, arena: ArenaData) -> void:
	var wins := [0, 0, 0]
	var round_ticks: Array[int] = []
	var damage := [0, 0]
	var outcomes := {}
	for seed_index in _matches:
		var r := _play(arena, a, b, seed_index * 97 + 13)
		wins[r["winner"]] += 1
		round_ticks.append_array(r["round_ticks"] as Array[int])
		damage[0] += r["damage"][0] as int
		damage[1] += r["damage"][1] as int
		outcomes[r["fingerprint"]] = true

	var played := float(maxi(wins[0] + wins[1] + wins[2], 1))
	round_ticks.sort()
	var median := 0.0
	if not round_ticks.is_empty():
		median = round_ticks[round_ticks.size() / 2] / float(SimConst.TICK_RATE)
	# Nothing in combat is random, so a pairing whose AI never consults its RNG plays the
	# same match every time. Say so, rather than presenting one match as a sample of 20.
	var note := ""
	if outcomes.size() == 1 and _matches > 1:
		note = "   [all %d matches identical: this AI pairing ignores its seed]" % _matches
	print("%-10s vs %-10s  win %4.0f%% / %4.0f%%  draws %d  median round %5.1fs  damage %6d / %6d%s" % [
		a.id, b.id, wins[0] / played * 100.0, wins[1] / played * 100.0, wins[2],
		median, damage[0], damage[1], note])


func _play(arena: ArenaData, a: HeroData, b: HeroData, match_seed: int) -> Dictionary:
	var hero_data: Array[HeroData] = [a, b]
	var sim := CombatSim.new(arena, hero_data, match_seed)
	var controllers: Array[HeroController] = [
		AIController.new(a.ai_profile, AIController.Difficulty.NORMAL, match_seed + 1, sim.geometry),
		AIController.new(b.ai_profile, AIController.Difficulty.NORMAL, match_seed + 2, sim.geometry),
	]
	var runner := MatchRunner.new()
	runner.setup(sim, controllers)

	var round_ticks: Array[int] = []
	var round_started := 0
	var ticks := 0
	while ticks < MAX_TICKS and sim.state.phase != MatchState.Phase.MATCH_OVER:
		runner.step_once()
		ticks += 1
		for ev in sim.state.events:
			if ev.kind == SimEvent.Kind.ROUND_ENDED:
				round_ticks.append(ticks - round_started)
				round_started = ticks
	var winner: int = sim.state.match_winner
	var damage := [sim.state.heroes[0].damage_dealt, sim.state.heroes[1].damage_dealt]
	runner.free()
	# Index 2 counts draws and matches that never resolved.
	return {
		"winner": winner if winner == 0 or winner == 1 else 2,
		"round_ticks": round_ticks,
		"damage": damage,
		"fingerprint": "%d:%d:%s" % [winner, ticks, damage],
	}
