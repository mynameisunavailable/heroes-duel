extends Control
## Character select: pick your hero, pick who you are fighting, pick how hard the AI
## plays, then start the match. Everything on screen is built from the hero roster, so
## adding a hero to data/roster.tres adds it here with no code change.

const DIFFICULTY_NAMES := ["Easy", "Normal"]
## Opponent option meaning "surprise me", kept out of the way of real hero ids.
const RANDOM_ID := "*random*"

var _player_id := ""
var _opponent_id := RANDOM_ID
var _difficulty := AIController.Difficulty.NORMAL
var _player_cards: Array[HeroCard] = []
var _opponent_cards: Array[HeroCard] = []
var _random_card: Button
var _difficulty_buttons: Array[Button] = []
var _rng := RandomNumberGenerator.new()

@onready var _player_grid: GridContainer = %PlayerGrid
@onready var _opponent_grid: GridContainer = %OpponentGrid
@onready var _random_button: Button = %RandomButton
@onready var _difficulty_row: HBoxContainer = %DifficultyRow
@onready var _fight_button: Button = %FightButton
@onready var _margin: MarginContainer = %Margin


func _ready() -> void:
	var roster := Game.roster
	if roster == null or roster.heroes.is_empty():
		push_error("No heroes to choose from: %s" % Game.ROSTER_PATH)
		return
	_rng.randomize()
	_difficulty = UserSettings.ai_difficulty
	_player_id = Game.next_match.hero_ids[0] if Game.next_match.hero_ids.size() > 0 else roster.heroes[0].id

	for hero in roster.heroes:
		_player_cards.append(_add_card(_player_grid, hero, Palette.TEAM[0], _on_player_picked))
		_opponent_cards.append(_add_card(_opponent_grid, hero, Palette.TEAM[1], _on_opponent_picked))
	_random_card = _random_button
	_random_card.pressed.connect(_on_opponent_picked.bind(RANDOM_ID))

	for i in DIFFICULTY_NAMES.size():
		var button := Button.new()
		button.text = DIFFICULTY_NAMES[i]
		button.custom_minimum_size = Vector2(130, 56)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_difficulty_picked.bind(i))
		_difficulty_row.add_child(button)
		_difficulty_buttons.append(button)

	_fight_button.pressed.connect(_start_match)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_refresh()


func _add_card(grid: GridContainer, hero: HeroData, color: Color, handler: Callable) -> HeroCard:
	var card := HeroCard.new()
	grid.add_child(card)
	card.setup(hero, color)
	card.pressed.connect(handler)
	return card


func _on_player_picked(hero_id: String) -> void:
	_player_id = hero_id
	_refresh()


func _on_opponent_picked(hero_id: String) -> void:
	_opponent_id = hero_id
	_refresh()


func _on_difficulty_picked(level: int) -> void:
	_difficulty = level
	UserSettings.set_value(&"ai_difficulty", level)
	_refresh()


func _refresh() -> void:
	for card in _player_cards:
		card.selected = card.hero.id == _player_id
	for card in _opponent_cards:
		card.selected = card.hero.id == _opponent_id
	_random_card.modulate = Color.WHITE if _opponent_id == RANDOM_ID else Color(1, 1, 1, 0.5)
	for i in _difficulty_buttons.size():
		_difficulty_buttons[i].modulate = Color.WHITE if i == _difficulty else Color(1, 1, 1, 0.45)
	var opponent := "a random hero" if _opponent_id == RANDOM_ID else Game.roster.find(_opponent_id).display_name
	_fight_button.text = "Fight %s" % opponent


## Keeps the screen clear of the notch and the home indicator on a phone.
func _apply_safe_area() -> void:
	var m := AppEnv.safe_margins(get_viewport())
	_margin.add_theme_constant_override(&"margin_left", int(m.x) + 24)
	_margin.add_theme_constant_override(&"margin_top", int(m.y) + 16)
	_margin.add_theme_constant_override(&"margin_right", int(m.z) + 24)
	_margin.add_theme_constant_override(&"margin_bottom", int(m.w) + 16)


func _start_match() -> void:
	var config := MatchConfig.default_vs_ai()
	config.hero_ids = PackedStringArray([_player_id, _resolve_opponent()])
	config.ai_difficulty = _difficulty
	config.rng_seed = _rng.randi() & 0x7FFFFFFF
	Game.start_match(config)


func _resolve_opponent() -> String:
	if _opponent_id != RANDOM_ID:
		return _opponent_id
	var ids := Game.roster.ids()
	return ids[_rng.randi_range(0, ids.size() - 1)]
