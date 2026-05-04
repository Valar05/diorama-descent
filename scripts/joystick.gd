extends Control

@export var max_distance: float = 50.0
@export var deadzone: float = 0.2

var base: Sprite2D
var pip: Node2D

var input_vector: Vector2 = Vector2.ZERO
var input_magnitude: float = 0.0
var origin_pos: Vector2 = Vector2.ZERO
var active_touch_id: int = -1


func _ready() -> void:
	base = $base
	pip = $base/JoystickPip
	base.visible = false
	pip.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x / 2.0 and active_touch_id == -1:
			active_touch_id = event.index
			origin_pos = event.position
			base.global_position = origin_pos
			pip.global_position = origin_pos
			base.visible = true
			pip.visible = true
		elif not event.pressed and event.index == active_touch_id:
			active_touch_id = -1
	elif event is InputEventScreenDrag and event.index == active_touch_id:
		_update_stick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x / 2.0 and active_touch_id == -1:
			active_touch_id = 0
			origin_pos = event.position
			base.global_position = origin_pos
			pip.global_position = origin_pos
			base.visible = true
			pip.visible = true
		elif not event.pressed and active_touch_id == 0:
			active_touch_id = -1
	elif event is InputEventMouseMotion and active_touch_id == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_stick(event.position)


func _update_stick(position: Vector2) -> void:
	var delta: Vector2 = position - origin_pos
	var dist: float = delta.length()
	var mag: float = min(dist / max_distance, 1.0)

	if mag < deadzone:
		input_vector = Vector2.ZERO
		input_magnitude = 0.0
		pip.global_position = origin_pos
		return

	input_vector = delta.normalized()
	input_magnitude = mag
	pip.global_position = origin_pos + input_vector * min(dist, max_distance)


func _process(_delta: float) -> void:
	if active_touch_id == -1:
		if base:
			pip.global_position = base.global_position
		input_vector = Vector2.ZERO
		input_magnitude = 0.0
		base.visible = false
		pip.visible = false


func get_input_vector() -> Vector2:
	if input_vector.length() < deadzone:
		return Vector2.ZERO

	return input_vector


func get_input_magnitude() -> float:
	return input_magnitude
