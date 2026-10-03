class_name HeroView
extends Node2D
## Read-only view of one HeroState: interpolated position, team ring, overhead HP bar,
## skill-readiness pips, and either the placeholder body or real art from HeroData.

const RING_RADIUS := 36.0
const BAR_SIZE := Vector2(64, 8)
const BAR_OFFSET := Vector2(-32, -62)

var hero: HeroState
var team_color := Color.WHITE
var show_pips := false
var _body: Node2D


func setup(p_hero: HeroState, p_team_color: Color, darken: bool, p_show_pips: bool) -> void:
	hero = p_hero
	team_color = p_team_color
	show_pips = p_show_pips
	var data := hero.data
	var placeholder := $Body as PlaceholderBody
	if data.sprite_frames != null:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = data.sprite_frames
		if data.sprite_frames.has_animation(&"idle"):
			anim.play(&"idle")
		_replace_body(placeholder, anim)
	elif data.sprite != null:
		var sprite := Sprite2D.new()
		sprite.texture = data.sprite
		_replace_body(placeholder, sprite)
	else:
		placeholder.setup(data, darken)
		_body = placeholder
	if darken and not (_body is PlaceholderBody):
		_body.modulate = Color(0.85, 0.85, 0.85)
	_body.scale = Vector2.ONE * data.art_scale
	position = hero.pos


func _replace_body(old: Node2D, new_body: Node2D) -> void:
	remove_child(old)
	old.queue_free()
	new_body.name = "Body"
	add_child(new_body)
	_body = new_body


func _process(_delta: float) -> void:
	if hero == null:
		return
	position = hero.prev_pos.lerp(hero.pos, Engine.get_physics_interpolation_fraction())
	modulate.a = 1.0 if hero.alive else 0.35
	if _body is PlaceholderBody:
		(_body as PlaceholderBody).facing = hero.facing
	elif hero.data.art_rotates_with_facing:
		_body.rotation = hero.facing.angle()
	elif _body is Sprite2D:
		(_body as Sprite2D).flip_h = hero.facing.x < 0.0
	elif _body is AnimatedSprite2D:
		(_body as AnimatedSprite2D).flip_h = hero.facing.x < 0.0
	queue_redraw()


func _draw() -> void:
	if hero == null:
		return
	draw_arc(Vector2.ZERO, RING_RADIUS, 0.0, TAU, 48, team_color, 4.0, true)
	draw_rect(Rect2(BAR_OFFSET, BAR_SIZE), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(BAR_OFFSET, Vector2(BAR_SIZE.x * hero.hp_ratio(), BAR_SIZE.y)), team_color)
	if show_pips:
		var count := hero.skill_cds.slot_count()
		for i in count:
			var p := Vector2((i - (count - 1) * 0.5) * 12.0, BAR_OFFSET.y - 10.0)
			if hero.skill_cds.is_ready(i):
				draw_circle(p, 4.0, team_color)
			else:
				draw_arc(p, 4.0, 0.0, TAU, 16, team_color, 1.5, true)
