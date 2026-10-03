class_name EffectData
extends Resource
## Base class of every effect primitive. Effects are pure data; the simulation's
## EffectApplier (milestone M1) interprets them, so all combat rules live in one place.


func describe() -> String:
	return ""
