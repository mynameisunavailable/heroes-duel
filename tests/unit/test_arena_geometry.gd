extends GutTest
## ArenaGeometry: the hand-rolled collision maths the simulation uses instead of
## Godot's physics engine.

const ARENA_PATH := "res://data/arenas/duel_arena.tres"

var _arena: ArenaData
var _geometry: ArenaGeometry


func before_each() -> void:
	_arena = load(ARENA_PATH) as ArenaData
	_geometry = ArenaGeometry.new(_arena)


func test_spawn_points_are_inside() -> void:
	for spawn in _arena.spawn_points:
		assert_true(_geometry.is_inside(spawn, SimConst.BODY_RADIUS),
			"spawn %s should fit a hero body" % spawn)


func test_constrain_pushes_a_point_outside_back_in() -> void:
	var outside := Vector2(-500.0, -500.0)
	var fixed := _geometry.constrain_circle(outside, SimConst.BODY_RADIUS)
	assert_true(_geometry.is_inside(fixed, SimConst.BODY_RADIUS - 0.1),
		"constrained point %s should be inside" % fixed)


func test_constrain_pushes_a_point_out_of_a_pillar() -> void:
	var pillar: Vector2 = _arena.pillar_centers[0]
	var fixed := _geometry.constrain_circle(pillar + Vector2(5.0, 0.0), SimConst.BODY_RADIUS)
	assert_gte(fixed.distance_to(pillar), _arena.pillar_radius + SimConst.BODY_RADIUS - 0.1,
		"should be pushed clear of the pillar")


func test_constrain_leaves_an_interior_point_alone() -> void:
	var centre := _arena.size * 0.5 + Vector2(0.0, 200.0)
	assert_eq(_geometry.constrain_circle(centre, SimConst.BODY_RADIUS), centre)


func test_pillar_blocks_the_line_between_the_spawns_through_it() -> void:
	var pillar: Vector2 = _arena.pillar_centers[0]
	var a := pillar - Vector2(300.0, 0.0)
	var b := pillar + Vector2(300.0, 0.0)
	assert_true(_geometry.segment_blocked_by_pillar(a, b, 0.0), "line through a pillar is blocked")
	assert_false(_geometry.segment_blocked_by_pillar(a, a + Vector2(0.0, 50.0), 0.0),
		"a short line clear of the pillar is not blocked")


func test_ray_stops_at_a_pillar() -> void:
	var pillar: Vector2 = _arena.pillar_centers[0]
	var origin := pillar - Vector2(300.0, 0.0)
	var distance := _geometry.ray_exit_distance(origin, Vector2.RIGHT, 1000.0, 0.0)
	assert_almost_eq(distance, 300.0 - _arena.pillar_radius, 1.0)


func test_ray_stops_at_a_wall() -> void:
	# x = 250 is clear of the pillars, which sit on the centre line.
	var origin := Vector2(250.0, 240.0)
	var distance := _geometry.ray_exit_distance(origin, Vector2.UP, 1000.0, 0.0)
	assert_almost_eq(distance, 240.0, 1.0, "should stop at the top wall")


func test_ray_is_capped_at_its_maximum() -> void:
	var origin := Vector2(250.0, 240.0)
	assert_eq(_geometry.ray_exit_distance(origin, Vector2.UP, 50.0, 0.0), 50.0)


func test_point_segment_distance() -> void:
	assert_almost_eq(ArenaGeometry.point_segment_distance(
		Vector2(0.0, 10.0), Vector2(-50.0, 0.0), Vector2(50.0, 0.0)), 10.0, 0.001)
	# Past the end of the segment, the nearest point is the end itself.
	assert_almost_eq(ArenaGeometry.point_segment_distance(
		Vector2(100.0, 0.0), Vector2(-50.0, 0.0), Vector2(50.0, 0.0)), 50.0, 0.001)
