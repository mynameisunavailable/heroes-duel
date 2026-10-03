extends GutTest
## CooldownTracker: integer-tick cooldowns per skill slot.


func test_starts_ready() -> void:
	var cds := CooldownTracker.new(3)
	assert_eq(cds.slot_count(), 3)
	for slot in 3:
		assert_true(cds.is_ready(slot), "slot %d should start ready" % slot)
		assert_eq(cds.fraction_remaining(slot), 0.0)


func test_counts_down_to_ready() -> void:
	var cds := CooldownTracker.new(1)
	cds.start(0, 3)
	assert_false(cds.is_ready(0))
	assert_eq(cds.remaining(0), 3)
	for _i in 3:
		cds.tick()
	assert_true(cds.is_ready(0))
	assert_eq(cds.remaining(0), 0)


func test_does_not_count_below_zero() -> void:
	var cds := CooldownTracker.new(1)
	cds.start(0, 1)
	for _i in 5:
		cds.tick()
	assert_eq(cds.remaining(0), 0)


func test_fraction_runs_from_one_to_zero() -> void:
	var cds := CooldownTracker.new(1)
	cds.start(0, 10)
	assert_almost_eq(cds.fraction_remaining(0), 1.0, 0.001)
	for _i in 5:
		cds.tick()
	assert_almost_eq(cds.fraction_remaining(0), 0.5, 0.001)
	for _i in 5:
		cds.tick()
	assert_eq(cds.fraction_remaining(0), 0.0)


func test_slots_are_independent() -> void:
	var cds := CooldownTracker.new(2)
	cds.start(0, 5)
	cds.tick()
	assert_eq(cds.remaining(0), 4)
	assert_true(cds.is_ready(1))


func test_reset_all_applies_to_every_slot() -> void:
	var cds := CooldownTracker.new(3)
	cds.reset_all(90)
	for slot in 3:
		assert_eq(cds.remaining(slot), 90)
