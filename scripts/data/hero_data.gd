class_name HeroData
extends Resource
## A playable hero: stats, normal attack, 2-3 skills, look and AI profile.
## Adding a hero or changing numbers only needs a new or edited .tres file.

enum AttackType { MELEE, PROJECTILE }
enum PlaceholderShape { SQUARE, TRIANGLE, CIRCLE, DIAMOND }

const MIN_SKILLS := 2
const MAX_SKILLS := 3

@export var id: String = ""
@export var display_name: String = ""
@export var archetype: String = ""

@export_group("Stats")
@export var max_hp: int = 1000
@export_range(50.0, 800.0, 5.0, "suffix:px/s") var move_speed: float = 300.0

@export_group("Normal attack")
@export var attack_type: AttackType = AttackType.MELEE
@export var attack_damage: int = 40
@export_range(0.0, 1000.0, 1.0, "suffix:px") var attack_range: float = 90.0
@export_range(0.05, 5.0, 0.05, "suffix:s") var attack_interval_s: float = 1.0
@export_range(0.0, 1.0, 0.01, "suffix:s") var attack_windup_s: float = 0.15
@export_range(0.0, 3000.0, 10.0, "suffix:px/s") var projectile_speed: float = 0.0
@export_range(0.0, 50.0, 1.0, "suffix:px") var projectile_radius: float = 6.0

@export_group("Skills")
@export var skills: Array[SkillData] = []

@export_group("Look")
## Drawn when neither sprite nor sprite_frames is set.
@export var placeholder_shape: PlaceholderShape = PlaceholderShape.CIRCLE
@export var color := Color.WHITE
@export var outline_color := Color.BLACK
@export var accent_color := Color.WHITE
@export var letter: String = ""
## Real art. Setting either replaces the placeholder with no code change. Leaving both
## empty also picks up art/heroes/<id>.png if that file exists; see ArtLibrary.
@export var sprite: Texture2D
@export var sprite_frames: SpriteFrames
## The art is scaled so its longest side is this many pixels, so an image of any size
## drops in at a sensible size. The hero's body is 56 px across. Set 0 to use the
## image's own pixel size instead.
@export_range(0.0, 400.0, 1.0, "suffix:px") var art_fit_px: float = 72.0
## Extra multiplier applied after the fit above.
@export var art_scale: float = 1.0
@export var art_rotates_with_facing := false

@export_group("AI")
@export var ai_profile: AIProfile


func attack_interval_ticks() -> int:
	return SimConst.to_ticks(attack_interval_s)


func attack_windup_ticks() -> int:
	return SimConst.to_ticks(attack_windup_s)


func get_validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("missing id")
	if max_hp <= 0:
		errors.append("max_hp must be > 0")
	if attack_windup_s >= attack_interval_s:
		errors.append("attack_windup_s must be shorter than attack_interval_s")
	if skills.size() < MIN_SKILLS or skills.size() > MAX_SKILLS:
		errors.append("needs %d-%d skills, has %d" % [MIN_SKILLS, MAX_SKILLS, skills.size()])
	if ai_profile == null:
		errors.append("missing ai_profile")
	for skill in skills:
		if skill == null:
			errors.append("null skill")
			continue
		for e in skill.get_validation_errors():
			errors.append("%s: %s" % [skill.id, e])
	return errors
