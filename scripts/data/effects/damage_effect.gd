class_name DamageEffect
extends EffectData
## Instant HP loss.

@export var amount: int = 0


func describe() -> String:
	return "Damage %d" % amount
