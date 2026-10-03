extends GutTest
## ArtLibrary: resolving hero, skill and arena pictures.

const SAMPLE_HERO_ID := "knight"


func test_a_missing_name_resolves_to_nothing() -> void:
	# Nothing is drawn rather than erroring, so a typo or a not-yet-imported file just
	# leaves the placeholder shape in place.
	assert_null(ArtLibrary.find(ArtLibrary.HERO_DIR, "no_such_hero"))
	assert_null(ArtLibrary.find(ArtLibrary.HERO_DIR, ""))


func test_a_file_named_after_the_hero_is_picked_up() -> void:
	var roster := load("res://data/roster.tres") as HeroRoster
	var hero := roster.find(SAMPLE_HERO_ID)
	assert_null(hero.sprite, "this test is about the file-name route, so the field must be empty")
	assert_not_null(ArtLibrary.hero_texture(hero),
		"art/%s.<ext> should be found; run --import if it was just added" % SAMPLE_HERO_ID)


func test_an_assigned_texture_wins_over_the_file_name() -> void:
	var roster := load("res://data/roster.tres") as HeroRoster
	var hero := (roster.find(SAMPLE_HERO_ID) as HeroData).duplicate() as HeroData
	var assigned := PlaceholderTexture2D.new()
	hero.sprite = assigned
	assert_eq(ArtLibrary.hero_texture(hero), assigned)


func test_a_hero_with_no_picture_resolves_to_nothing() -> void:
	var hero := HeroData.new()
	hero.id = "nameless_hero"
	assert_null(ArtLibrary.hero_texture(hero))


func test_fit_scale_sizes_the_longest_side() -> void:
	var texture := PlaceholderTexture2D.new()
	texture.size = Vector2(200, 100)
	assert_almost_eq(ArtLibrary.fit_scale(texture, 72.0, 1.0), 0.36, 0.0001)
	# The extra scale multiplies the fit.
	assert_almost_eq(ArtLibrary.fit_scale(texture, 72.0, 2.0), 0.72, 0.0001)


func test_a_fit_of_zero_keeps_the_image_at_its_own_size() -> void:
	var texture := PlaceholderTexture2D.new()
	texture.size = Vector2(200, 100)
	assert_eq(ArtLibrary.fit_scale(texture, 0.0, 1.5), 1.5)


func test_fit_scale_tolerates_a_missing_texture() -> void:
	assert_eq(ArtLibrary.fit_scale(null, 72.0, 1.0), 1.0)
