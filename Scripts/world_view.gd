extends Camera3D

@onready var aim_rotation = $AimRotation
@onready var spawn_position = $AimRotation/SpawnPosition
@onready var aim_plane : AnimationPlayer = $AimPlane
@onready var animation_player = $AnimationPlayer
@export var spawn_shootable : PackedScene

@export var shake_curve : Curve

var screen_position : Vector2

func _input(event) -> void:
	# Mouse in viewport coordinates.
	if event is InputEventMouseButton:
		#todo check left right mouse button :)
		if event.is_pressed():
			charge()
		if event.is_released():
			shoot(event.position)
	elif event is InputEventMouseMotion:
		screen_position = event.position

var object_to_shoot : RigidBody3D
var charge_duration : float
var rotated_fast : bool
var rotate_object_tween : Tween
var push_back_camera_tween : Tween

func charge() -> void:
	if object_to_shoot != null:
		return
	object_to_shoot = spawn_shootable.instantiate()
	spawn_position.add_child(object_to_shoot)
	object_to_shoot.freeze = true
	charge_duration = 0
	rotated_fast = false

func _process(delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_rect = get_viewport().get_visible_rect()
	if not viewport_rect.has_point(mouse_pos):
		screen_position = get_viewport().get_visible_rect().size / 2
	
	handle_camera_rotation(delta)
	
	if object_to_shoot != null:
		handle_object_aim_rotation(delta)
		handle_camera_shake()

func handle_camera_rotation(delta: float) -> void:
	
	var relative_position = screen_position / get_viewport().get_visible_rect().size.y
	relative_position.x = (relative_position.x * 2) - 1
	relative_position.y = (relative_position.y * 2) - 1
	var relative_angle = relative_position * fov/2
	relative_angle *= -0.003
	
	var current_camera_quat = basis.get_rotation_quaternion()
	var target_camera_quat = quaternion.from_euler(Vector3(relative_angle.y, relative_angle.x, 0))
	var camera_rotation_speed = 2.0
	var new_camera_quat = current_camera_quat.slerp(target_camera_quat, delta * camera_rotation_speed)
	basis = Basis(new_camera_quat)
	
func handle_object_aim_rotation(delta: float) -> void:
	spawn_position.rotate_z(charge_duration / 5)
	charge_duration += delta
	
	var direction = project_ray_normal(screen_position)
	var target_basis = Basis().looking_at(direction, Vector3.UP)

	var current_quat = aim_rotation.basis.get_rotation_quaternion()
	var target_quat = target_basis.get_rotation_quaternion()
	
	var aim_rotation_speed = 2.0
	var new_quat = current_quat.slerp(target_quat, delta * aim_rotation_speed)
	aim_rotation.transform.basis = Basis(new_quat)
			
	if rotated_fast == false and charge_duration > 1:
		rotate_object_tween = get_tree().create_tween()
		
		var target_rotation = Vector3(
			deg_to_rad(90),
			deg_to_rad(0),
			deg_to_rad(0)
		)
		
		rotate_object_tween.tween_property(object_to_shoot, "rotation", target_rotation, 1)
		rotated_fast = true

func handle_camera_shake() -> void:
	var shake_strength = shake_curve.sample(charge_duration)
	position = Vector3(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength), 0)

func shoot(screen_position) -> void:
	if object_to_shoot == null:
		print("no object")
		return
	
	if rotate_object_tween != null:
		rotate_object_tween.stop()
	
	var from = project_ray_origin(screen_position)
	var ray_length = 2
	var direction = project_ray_normal(screen_position) * ray_length
	var target_position = from + direction
	
	object_to_shoot.reparent(get_parent())
	object_to_shoot.freeze = false

	# i shouldn't rotate this by this horizon, i should push the applied force vector up and down
	var applied_force = target_position - object_to_shoot.global_position
	applied_force += applied_force * charge_duration * 3
	object_to_shoot.apply_central_impulse(applied_force)
	
	
	push_back_camera_tween = get_tree().create_tween()
	var original_position = position
	var push_position = Vector3(0, 0, 0.25 * charge_duration)
	push_back_camera_tween.tween_property(self, "position", push_position, 0.06).set_trans(Tween.TRANS_BOUNCE)
	push_back_camera_tween.tween_property(self, "position", original_position, 0.9)
	
	object_to_shoot = null
	charge_duration = 0
	rotated_fast = false
	
	
	#animation_player.play("camera_push_back")
	
	
