class_name CooldownTracker
extends RefCounted
## Integer-tick cooldowns for a fixed number of skill slots.

var _remaining := PackedInt32Array()
var _total := PackedInt32Array()


func _init(p_slot_count: int) -> void:
	_remaining.resize(p_slot_count)
	_total.resize(p_slot_count)
	_remaining.fill(0)
	_total.fill(1)


func slot_count() -> int:
	return _remaining.size()


func start(slot: int, ticks: int) -> void:
	_remaining[slot] = maxi(ticks, 0)
	_total[slot] = maxi(ticks, 1)


func tick() -> void:
	for i in _remaining.size():
		if _remaining[i] > 0:
			_remaining[i] -= 1


func remaining(slot: int) -> int:
	return _remaining[slot]


func total(slot: int) -> int:
	return _total[slot]


func is_ready(slot: int) -> bool:
	return _remaining[slot] == 0


## 1.0 right after starting, 0.0 when ready.
func fraction_remaining(slot: int) -> float:
	if _remaining[slot] <= 0:
		return 0.0
	return float(_remaining[slot]) / float(_total[slot])


func reset_all(ticks: int) -> void:
	for i in _remaining.size():
		start(i, ticks)
