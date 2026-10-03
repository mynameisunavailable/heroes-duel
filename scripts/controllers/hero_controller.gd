class_name HeroController
extends RefCounted
## Produces one HeroCommand per simulation tick for one hero. Subclasses: the local
## player (touch + keyboard), the AI and, in milestone M6, a network peer.

var hero_index: int = -1


func build_command(tick: int, _state: MatchState) -> HeroCommand:
	return HeroCommand.idle(tick)


## Clears any held or latched input, e.g. when the match is paused.
func reset() -> void:
	pass
