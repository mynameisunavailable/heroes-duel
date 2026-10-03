class_name ArtLibrary
extends RefCounted
## Finds the artwork for heroes, skills and arenas.
##
## Two ways to set a picture, in priority order:
##
## 1. Whatever is assigned on the resource itself (HeroData.sprite, SkillData.icon,
##    ArenaData.floor_texture) is used as-is. Assign these in the Godot editor when you
##    want one hero to use art that is not named after it, or to share one image.
##
## 2. Otherwise a file named after the thing's id, in the matching art/ folder, is
##    picked up automatically: art/heroes/knight.png becomes the Knight's body. This
##    needs no resource editing and no code changes.
##
## Godot only sees an image once it has been imported, which happens when the editor
## opens or when `godot --headless --path . --import` runs. Until then the placeholder
## shape is drawn, which is why nothing breaks if a file is missing or misspelled.

const HERO_DIR := "res://art/heroes"
const SKILL_DIR := "res://art/skills"
const ARENA_DIR := "res://art/arena"
## Tried in this order, so a .png beats a .svg of the same name.
const EXTENSIONS: Array[String] = [".png", ".svg", ".webp", ".jpg", ".jpeg"]


static func hero_texture(hero: HeroData) -> Texture2D:
	if hero == null:
		return null
	if hero.sprite != null:
		return hero.sprite
	return find(HERO_DIR, hero.id)


static func skill_icon(skill: SkillData) -> Texture2D:
	if skill == null:
		return null
	if skill.icon != null:
		return skill.icon
	return find(SKILL_DIR, skill.id)


static func arena_floor(arena: ArenaData) -> Texture2D:
	if arena == null:
		return null
	if arena.floor_texture != null:
		return arena.floor_texture
	return find(ARENA_DIR, arena.id)


## The first image in `dir` named `base_name`, or null when there is none.
static func find(dir: String, base_name: String) -> Texture2D:
	if base_name.is_empty():
		return null
	for extension in EXTENSIONS:
		var path := "%s/%s%s" % [dir, base_name, extension]
		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			if texture != null:
				return texture
	return null


## Scale that fits `texture` into `fit_px` across its longest side, so an image of any
## size drops in at a sensible size. A fit of 0 leaves the image at its own pixel size.
static func fit_scale(texture: Texture2D, fit_px: float, extra_scale: float) -> float:
	if texture == null or fit_px <= 0.0:
		return extra_scale
	var longest := float(maxi(texture.get_width(), texture.get_height()))
	if longest <= 0.0:
		return extra_scale
	return fit_px / longest * extra_scale
