class_name ArenaGeometry
extends RefCounted
## Pure geometry for the convex arena polygon and its round pillars. No physics engine:
## every query is plain maths, so the same code runs offline, on a headless server and
## inside client-side prediction.

var data: ArenaData
var _normals := PackedVector2Array()
var _offsets := PackedFloat32Array()


func _init(p_data: ArenaData) -> void:
	data = p_data
	var poly := p_data.polygon
	var centroid := Vector2.ZERO
	for p in poly:
		centroid += p
	centroid /= float(maxi(poly.size(), 1))
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var n := (b - a).orthogonal().normalized()
		if n.dot(centroid - a) < 0.0:
			n = -n
		_normals.append(n)
		_offsets.append(n.dot(a))


## Pushes a circle of radius r back inside the arena walls and out of the pillars.
func constrain_circle(p: Vector2, r: float) -> Vector2:
	var out := p
	for _pass in 2:
		for i in _normals.size():
			var d := _normals[i].dot(out) - _offsets[i]
			if d < r:
				out += _normals[i] * (r - d)
		for c in data.pillar_centers:
			var min_dist := r + data.pillar_radius
			var delta := out - c
			var dist := delta.length()
			if dist < min_dist:
				var dir: Vector2 = delta / dist if dist > 0.001 else Vector2.RIGHT
				out = c + dir * min_dist
	return out


func is_inside(p: Vector2, r: float) -> bool:
	for i in _normals.size():
		if _normals[i].dot(p) - _offsets[i] < r:
			return false
	for c in data.pillar_centers:
		if p.distance_to(c) < r + data.pillar_radius:
			return false
	return true


## True if the segment a-b, thickened by pad, touches a pillar. Used for line of sight.
func segment_blocked_by_pillar(a: Vector2, b: Vector2, pad: float) -> bool:
	for c in data.pillar_centers:
		if point_segment_distance(c, a, b) < data.pillar_radius + pad:
			return true
	return false


## How far a ray from `origin` travels before it leaves the arena or meets a pillar,
## capped at max_distance. Used to clip skill telegraphs to what can actually be hit.
func ray_exit_distance(origin: Vector2, dir: Vector2, max_distance: float, pad: float = 0.0) -> float:
	var best := max_distance
	for i in _normals.size():
		var denom := _normals[i].dot(dir)
		if denom >= -0.0001:
			continue
		var t := (_normals[i].dot(origin) - _offsets[i] - pad) / -denom
		if t >= 0.0:
			best = minf(best, t)
	for c in data.pillar_centers:
		var t := _ray_circle_distance(origin, dir, c, data.pillar_radius + pad)
		if t >= 0.0:
			best = minf(best, t)
	return maxf(best, 0.0)


## Smallest non-negative distance along the ray at which it meets the circle, or -1.
static func _ray_circle_distance(origin: Vector2, dir: Vector2, centre: Vector2, radius: float) -> float:
	var to_centre := origin - centre
	var b := to_centre.dot(dir)
	var c := to_centre.length_squared() - radius * radius
	if c > 0.0 and b > 0.0:
		return -1.0
	var disc := b * b - c
	if disc < 0.0:
		return -1.0
	var t := -b - sqrt(disc)
	return t if t >= 0.0 else -1.0


static func point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq <= 0.000001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
