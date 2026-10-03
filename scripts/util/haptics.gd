class_name Haptics
extends RefCounted
## Thin wrapper over Input.vibrate_handheld with a few named pulse strengths.
## Does nothing on desktop.

enum Kind { LIGHT, MEDIUM, HEAVY, SELECTION }

const DURATION_MS := [12, 22, 40, 8]
const AMPLITUDE := [0.35, 0.6, 1.0, 0.25]


static func pulse(kind: Kind, enabled: bool) -> void:
	if not enabled or not OS.has_feature("mobile"):
		return
	Input.vibrate_handheld(DURATION_MS[kind], AMPLITUDE[kind])
