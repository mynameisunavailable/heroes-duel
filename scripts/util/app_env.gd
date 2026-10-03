class_name AppEnv
extends RefCounted
## Queries about how and where the game is running.


static func is_dedicated_server() -> bool:
	return OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_user_args()


static func is_mobile() -> bool:
	return OS.has_feature("mobile")


## Safe-area margins (left, top, right, bottom) in viewport units, so drawn HUD elements
## clear the notch / Dynamic Island and the home indicator. Zero on desktop, where the
## safe-area API reports the monitor's usable rect instead.
static func safe_margins(viewport: Viewport) -> Vector4:
	if not is_mobile():
		return Vector4.ZERO
	var window := Vector2(DisplayServer.window_get_size())
	if window.x <= 0.0 or window.y <= 0.0:
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var to_viewport := viewport.get_visible_rect().size / window
	return Vector4(
		safe.position.x * to_viewport.x,
		safe.position.y * to_viewport.y,
		(window.x - safe.end.x) * to_viewport.x,
		(window.y - safe.end.y) * to_viewport.y)
