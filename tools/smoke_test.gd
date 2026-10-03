extends SceneTree
## Headless smoke test: validates hero data, then plays a full AI-vs-AI match twice with
## the same seed. It checks the match actually resolves and that the simulation is
## deterministic. Exits 0 on success, 1 on failure.
## Run: godot --headless --path . -s res://tools/smoke_test.gd

## Generous cap: a best-of-5 of full-length rounds would be about 19,500 ticks.
const MAX_TICKS := 30000


func _initialize() -> void:
	var failure := _run()
	if failure.is_empty():
		print("SMOKE OK")
		quit(0)
	else:
		printerr("SMOKE FAIL: " + failure)
		quit(1)


func _run() -> String:
	var roster := load("res://data/roster.tres") as HeroRoster
	var arena := load("res://data/arenas/duel_arena.tres") as ArenaData
	if roster == null or arena == null:
		return "could not load roster or arena"
	for hero in roster.heroes:
		var errors := hero.get_validation_errors()
		if not errors.is_empty():
			return "%s: %s" % [hero.id, ", ".join(errors)]
	var knight := roster.find("knight")
	var ranger := roster.find("ranger")
	if knight == null or ranger == null:
		return "knight or ranger missing from roster"

	var first := _play_match(arena, knight, ranger)
	if not (first["error"] as String).is_empty():
		return first["error"]
	var second := _play_match(arena, knight, ranger)
	if first["checksum"] != second["checksum"] or first["ticks"] != second["ticks"]:
		return "same seed and inputs produced different results"

	print("ticks=%d rounds=%d winner=%s damage=%s skills=%d attacks=%d kos=%d checksum=%d" % [
		first["ticks"], first["rounds"], first["winner"], first["damage"],
		first["skills"], first["attacks"], first["kos"], first["checksum"]])
	return ""


func _play_match(arena: ArenaData, a: HeroData, b: HeroData) -> Dictionary:
	var hero_data: Array[HeroData] = [a, b]
	var sim := CombatSim.new(arena, hero_data, 7)
	var controllers: Array[HeroController] = [
		AIController.new(a.ai_profile, AIController.Difficulty.NORMAL, 1, sim.geometry),
		AIController.new(b.ai_profile, AIController.Difficulty.NORMAL, 2, sim.geometry),
	]
	var runner := MatchRunner.new()
	runner.setup(sim, controllers)

	var skills := 0
	var attacks := 0
	var kos := 0
	var rounds := 0
	var error := ""
	var ticks := 0
	while ticks < MAX_TICKS and sim.state.phase != MatchState.Phase.MATCH_OVER:
		runner.step_once()
		ticks += 1
		for ev in sim.state.events:
			match ev.kind:
				SimEvent.Kind.SKILL_FIRED: skills += 1
				SimEvent.Kind.ATTACK_STARTED: attacks += 1
				SimEvent.Kind.KO: kos += 1
				SimEvent.Kind.ROUND_ENDED: rounds += 1
		if error.is_empty():
			error = _check_invariants(sim)
	var checksum := sim.state.checksum()
	var damage := "%d/%d" % [sim.state.heroes[0].damage_dealt, sim.state.heroes[1].damage_dealt]
	runner.free()

	if error.is_empty() and sim.state.phase != MatchState.Phase.MATCH_OVER:
		error = "match did not finish within %d ticks" % MAX_TICKS
	if error.is_empty() and skills == 0:
		error = "no skill was ever fired"
	if error.is_empty() and kos == 0:
		error = "no hero was ever knocked out"
	if error.is_empty() and rounds < SimConst.ROUNDS_TO_WIN:
		error = "match ended after only %d round(s)" % rounds
	# Each hero must land hits of their own. A one-sided total means a whole damage path
	# (ranged projectiles, or skills) is silently broken.
	for h in sim.state.heroes:
		if error.is_empty() and h.damage_dealt == 0:
			error = "hero %d (%s) dealt no damage all match" % [h.index, h.data.id]
	return {
		"error": error, "checksum": checksum, "ticks": ticks, "rounds": rounds,
		"winner": sim.state.match_winner, "damage": damage,
		"skills": skills, "attacks": attacks, "kos": kos,
	}


func _check_invariants(sim: CombatSim) -> String:
	for h in sim.state.heroes:
		if not sim.geometry.is_inside(h.pos, SimConst.BODY_RADIUS - 0.1):
			return "hero %d left the arena at tick %d (%s)" % [h.index, sim.state.tick, h.pos]
		if h.hp < 0 or h.hp > h.max_hp:
			return "hero %d has impossible hp %d at tick %d" % [h.index, h.hp, sim.state.tick]
		if h.alive != (h.hp > 0):
			return "hero %d alive flag disagrees with hp at tick %d" % [h.index, sim.state.tick]
	if sim.state.projectiles.size() > 64:
		return "projectile leak: %d alive at tick %d" % [sim.state.projectiles.size(), sim.state.tick]
	return ""
