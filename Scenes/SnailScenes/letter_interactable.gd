extends Node3D

@export var popup: Node3D
@export var bubble: Sprite3D
@export var text: Label3D

@export var speed := 5.0
@export var text_delay := 0.25   # when text starts appearing
@export var text_softness := 1.6 # easing strength
@export var rise_height := 0.3   # how much the popup moves up

var is_active := false
var t := 0.0   # 0..1 animation progress
var base_position: Vector3      # store original popup position

func _ready():
	t = 0.0
	base_position = popup.global_position   # store initial position
	popup.visible = false
	_apply_visuals()

func _process(delta):
	var target := 1.0 if is_active else 0.0
	t = move_toward(t, target, speed * delta)

	# Visibility gate
	popup.visible = t > 0.01

	_apply_visuals()

	# Face camera (stable)
	if popup.visible:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var dir = cam.global_position - popup.global_position
			dir.y = 0
			if dir.length() > 0.001:
				popup.rotation.y = atan2(dir.x, dir.z)

func _apply_visuals():
	# --- Rise effect ---
	var rise_t: float = ease(t, 0.6)
	popup.global_position.y = base_position.y + rise_t * rise_height

	# --- Bubble: scale + fade together ---
	var bubble_alpha: float = rise_t
	bubble.scale = Vector3.ONE * bubble_alpha
	bubble.modulate.a = bubble_alpha

	# --- Text: delayed + softer fade ---
	var text_t: float = clamp((t - text_delay) / (1.0 - text_delay), 0.0, 1.0)
	text_t = pow(text_t, text_softness)
	text.modulate.a = text_t

func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		is_active = true

func _on_area_3d_body_exited(body):
	if body.is_in_group("player"):
		is_active = false
