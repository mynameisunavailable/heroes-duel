class_name HeroCard
extends Control
## One pickable hero on the character select screen: a preview of the hero, their name,
## archetype, headline stats and a dot per skill. Built from HeroData, so a new hero in
## the roster appears here with no code change.
##
## Handles both touch and mouse, because menus are driven by a cursor on desktop and a
## finger on a phone.

signal pressed(hero_id: String)

## Sized so that four heroes in a 2x2 grid still leave room for the footer at 720 tall.
const CARD_SIZE := Vector2(176, 216)
const PREVIEW_CENTRE := Vector2(88, 78)
const PREVIEW_FIT_PX := 80.0

var hero: HeroData
var team_color := Color.WHITE
var selected := false:
	set(value):
		if value != selected:
			selected = value
			queue_redraw()

var _preview: Node2D
var _held := false


func setup(p_hero: HeroData, p_team_color: Color) -> void:
	hero = p_hero
	team_color = p_team_color
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	_preview = _make_preview(p_hero)
	_preview.position = PREVIEW_CENTRE
	add_child(_preview)
	tooltip_text = "%s - %s" % [p_hero.display_name, p_hero.archetype]
	queue_redraw()


## A still, forward-facing version of the hero: their picture if they have one, else the
## placeholder shape, scaled to fit the card.
static func _make_preview(data: HeroData) -> Node2D:
	var texture := ArtLibrary.hero_texture(data)
	if texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.scale = Vector2.ONE * ArtLibrary.fit_scale(texture, PREVIEW_FIT_PX, 1.0)
		return sprite
	var body := PlaceholderBody.new()
	body.setup(data, false)
	# The placeholder shapes are drawn about 80 px across at their natural size.
	body.scale = Vector2.ONE * (PREVIEW_FIT_PX / 80.0)
	return body


func _gui_input(event: InputEvent) -> void:
	var press := false
	var release := false
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		press = touch.pressed
		release = not touch.pressed and not touch.canceled
	elif event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT:
			return
		press = click.pressed
		release = not click.pressed
	else:
		return

	if press:
		_held = true
		queue_redraw()
	elif release:
		if _held:
			pressed.emit(hero.id)
		_held = false
		queue_redraw()
	accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _held:
		_held = false
		queue_redraw()


func _draw() -> void:
	if hero == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var fill := Color(0.14, 0.16, 0.21) if not _held else Color(0.2, 0.23, 0.3)
	draw_rect(rect, fill)
	var border := team_color if selected else Color(1, 1, 1, 0.18)
	draw_rect(rect, border, false, 3.0 if selected else 1.5)
	if selected:
		# A bar along the top edge, so the choice reads at a glance on a small screen.
		draw_rect(Rect2(0.0, 0.0, size.x, 5.0), team_color)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0.0, 150.0), hero.display_name,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color.WHITE)
	draw_string(font, Vector2(0.0, 172.0), hero.archetype,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(1, 1, 1, 0.55))
	draw_string(font, Vector2(0.0, 192.0), "%d HP   %d dmg" % [hero.max_hp, hero.attack_damage],
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(1, 1, 1, 0.45))

	# One dot per skill, so a 2-skill and a 3-skill hero are told apart before picking.
	var count := hero.skills.size()
	for i in count:
		var centre := Vector2(size.x * 0.5 + (i - (count - 1) * 0.5) * 20.0, 206.0)
		draw_circle(centre, 5.0, hero.skills[i].telegraph_color)
		draw_arc(centre, 5.0, 0.0, TAU, 16, Color(1, 1, 1, 0.5), 1.0, true)
