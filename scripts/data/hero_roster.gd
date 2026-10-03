class_name HeroRoster
extends Resource
## The list of playable heroes. Listed explicitly because exported builds remap resource
## files, which makes scanning a directory unreliable.

@export var heroes: Array[HeroData] = []


func find(hero_id: String) -> HeroData:
	for hero in heroes:
		if hero != null and hero.id == hero_id:
			return hero
	return null


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for hero in heroes:
		if hero != null:
			out.append(hero.id)
	return out
