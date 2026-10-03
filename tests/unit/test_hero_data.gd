extends GutTest
## The shipped hero data must satisfy the rules the simulation and HUD rely on.

const ROSTER_PATH := "res://data/roster.tres"

var _roster: HeroRoster


func before_each() -> void:
	_roster = load(ROSTER_PATH) as HeroRoster


func test_roster_loads() -> void:
	assert_not_null(_roster)
	assert_gt(_roster.heroes.size(), 0)


func test_every_hero_validates() -> void:
	for hero in _roster.heroes:
		var errors := hero.get_validation_errors()
		assert_eq(errors.size(), 0, "%s: %s" % [hero.id, ", ".join(errors)])


func test_find_works_and_misses_cleanly() -> void:
	assert_not_null(_roster.find("knight"))
	assert_null(_roster.find("no_such_hero"))


func test_roster_covers_both_skill_counts() -> void:
	# The HUD generates 2- and 3-button layouts from data, so both must be exercised.
	var counts := {}
	for hero in _roster.heroes:
		counts[hero.skills.size()] = true
	assert_true(counts.has(2), "a hero with exactly 2 skills")
	assert_true(counts.has(3), "a hero with exactly 3 skills")


func test_validation_rejects_too_few_skills() -> void:
	var hero := HeroData.new()
	hero.id = "stub"
	hero.ai_profile = AIProfile.new()
	hero.skills = []
	assert_gt(hero.get_validation_errors().size(), 0, "0 skills should be rejected")


func test_validation_rejects_a_windup_longer_than_the_interval() -> void:
	var hero := load("res://data/heroes/knight.tres").duplicate() as HeroData
	hero.attack_windup_s = hero.attack_interval_s + 0.1
	var errors := hero.get_validation_errors()
	assert_gt(errors.size(), 0, "windup must be shorter than the attack interval")


func test_seconds_convert_to_whole_ticks() -> void:
	var knight := _roster.find("knight")
	assert_eq(knight.attack_interval_ticks(), SimConst.TICK_RATE)
	assert_eq(knight.attack_windup_ticks(), 9)
	assert_eq(knight.skills[0].cooldown_ticks(), 600)


func test_cooldowns_stay_inside_the_design_band() -> void:
	for hero in _roster.heroes:
		for skill in hero.skills:
			assert_between(skill.cooldown_s, 6.0, 12.0,
				"%s/%s cooldown is outside the 6-12 s band" % [hero.id, skill.id])
