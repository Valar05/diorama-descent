extends Sprite3D
class_name ActorVisual

@export var front_texture: Texture2D
@export var front_outline_texture: Texture2D
@export var back_texture: Texture2D
@export var back_outline_texture: Texture2D
@export var side_texture: Texture2D
@export var side_outline_texture: Texture2D
@export var shadow_texture: Texture2D
var spawn_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	spawn_offset = position
	reset_visuals()


func reset_visuals() -> void:
	_reset_visuals()


func _reset_visuals() -> void:
	flip_h = false
	_apply_body_texture(front_texture, front_outline_texture)


func set_facing(direction: Vector2i) -> void:
	if direction.x > 0:
		_apply_body_texture(side_texture, side_outline_texture)
		flip_h = false
	elif direction.x < 0:
		_apply_body_texture(side_texture, side_outline_texture)
		flip_h = true
	elif direction.y > 0:
		_apply_body_texture(front_texture, front_outline_texture)
		flip_h = false
	elif direction.y < 0:
		_apply_body_texture(back_texture, back_outline_texture)
		flip_h = false


func get_body() -> Sprite3D:
	return self


func get_shadow() -> Sprite3D:
	return _get_shadow()


func _apply_body_texture(display_texture: Texture2D, outline_texture: Texture2D) -> void:
	texture = display_texture

	var material: ShaderMaterial = material_override as ShaderMaterial

	if material == null:
		return

	material.set_shader_parameter("albedo_tex", outline_texture if outline_texture != null else display_texture)


func _get_shadow() -> Sprite3D:
	return get_node_or_null("Shadow") as Sprite3D
