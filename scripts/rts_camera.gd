extends Node3D
## Câmera RTS para celular: inclinação fixa, arrastar com 1 dedo move, pinça faz zoom.
## No computador: arrastar com o botão esquerdo move, roda do mouse faz zoom.

@export var pitch_deg := 52.0
@export var fov := 38.0
@export var distance := 82.0
@export var min_distance := 40.0
@export var max_distance := 170.0
@export var bounds := Rect2(-90, -60, 180, 120)
@export var handle_input := true   # false quando outro script cuida do toque (o jogo)

var cam: Camera3D
var _touches: Dictionary = {}
var _pinch_start := 0.0
var _dist_start := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = fov
	cam.far = 800.0
	add_child(cam)
	cam.current = true
	_update_cam()


func _update_cam() -> void:
	distance = clampf(distance, min_distance, max_distance)
	var p := deg_to_rad(pitch_deg)
	cam.position = Vector3(0, sin(p) * distance, cos(p) * distance)
	cam.rotation = Vector3(-p, 0, 0)


func _pan(screen_delta: Vector2) -> void:
	var vh := get_viewport().get_visible_rect().size.y
	var k := 2.0 * distance * tan(deg_to_rad(fov) / 2.0) / vh
	position.x = clampf(position.x - screen_delta.x * k, bounds.position.x, bounds.end.x)
	position.z = clampf(position.z - screen_delta.y * k / sin(deg_to_rad(pitch_deg)), bounds.position.y, bounds.end.y)


func zoom_by(f: float) -> void:
	distance *= f
	_update_cam()


func focus(p: Vector3) -> void:
	position.x = clampf(p.x, bounds.position.x, bounds.end.x)
	position.z = clampf(p.z, bounds.position.y, bounds.end.y)


func pan(screen_delta: Vector2) -> void:
	_pan(screen_delta)


func _unhandled_input(event: InputEvent) -> void:
	if not handle_input:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() == 2:
			var v: Array = _touches.values()
			_pinch_start = (v[0] as Vector2).distance_to(v[1])
			_dist_start = distance
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_pan(event.relative)
		elif _touches.size() == 2 and _pinch_start > 0.0:
			var v: Array = _touches.values()
			var d := (v[0] as Vector2).distance_to(v[1])
			distance = _dist_start * _pinch_start / maxf(d, 1.0)
			_update_cam()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_pan(event.relative)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance *= 0.9
			_update_cam()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance *= 1.1
			_update_cam()
