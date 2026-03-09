class_name WorldView extends Camera3D

@onready var aim_rotation = $AimRotation
@onready var aim_transform = aim_rotation.transform
@onready var spawn_position = $AimRotation/SpawnPosition
@onready var spawn_transform = spawn_position.transform
@onready var aim_plane : AnimationPlayer = $AimPlane
@onready var animation_player = $AnimationPlayer

@export var spawn_shootable : PackedScene
@export var shake_curve : Curve

# -------------------------
# SHOOT STRENGTH
# -------------------------
@export var shoot_strength : float = 1.0

# -------------------------
# THROW ARC
# -------------------------
@export var throw_arc : float = 0.25   # upward arc multiplier

# -------------------------
# FOV SETTINGS
# -------------------------
@export var normal_fov : float = 70.0
@export var charge_fov : float = 55.0
@export var fov_speed : float = 6.0

# -------------------------
# RECOIL SETTINGS
# -------------------------
@export var recoil_kickback : float = 0.35
@export var recoil_tilt : float = 3.0
@export var recoil_spring : float = 14.0
@export var recoil_damping : float = 10.0

var recoil_pos : float = 0.0
var recoil_pos_vel : float = 0.0
var recoil_rot : float = 0.0
var recoil_rot_vel : float = 0.0

# -------------------------
# QUICK SHOOT SHAKE
# -------------------------
var shoot_shake_timer : float = 0.0
@export var shoot_shake_duration : float = 0.08
@export var shoot_shake_strength : float = 0.1

# -------------------------
# HIT SHAKE
# -------------------------
var hit_shake_timer : float = 0.0
var hit_shake_duration : float = 0.15
var hit_shake_strength : float = 0.15

# -------------------------
# BASE CAMERA STATE
# -------------------------
var base_position : Vector3
var base_rotation : Vector3

var screen_position : Vector2

# -------------------------
# SHOOTING STATE
# -------------------------
var object_to_shoot : RigidBody3D
var charge_duration : float
var rotated_fast : bool
var rotate_object_tween : Tween
var charging : bool

# -------------------------
# READY
# -------------------------
func _ready() -> void:
	GlobalManager.world_view = self
	fov = normal_fov
	base_position = position
	base_rotation = rotation

# -------------------------
# INPUT
# -------------------------
func _input(event) -> void:
	if event is InputEventMouseButton:
		if event.is_pressed():
			charge()
		if event.is_released():
			shoot(event.position)
	elif event is InputEventMouseMotion:
		screen_position = event.position

# -------------------------
# PROCESS
# -------------------------
func _process(delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_rect = get_viewport().get_visible_rect()
	if not viewport_rect.has_point(mouse_pos):
		screen_position = viewport_rect.size / 2

	handle_fov(delta)
	handle_recoil(delta)

	handle_hit_shake(delta)
	handle_quick_shoot_shake(delta)

	if charging:
		handle_object_aim_rotation(delta)

# -------------------------
# FOV
# -------------------------
func handle_fov(delta: float) -> void:
	var target_fov = normal_fov
	if charging:
		var charge_ratio = clamp(charge_duration / 2.0, 0.0, 1.0)
		target_fov = lerp(normal_fov, charge_fov, charge_ratio)
	fov = lerp(fov, target_fov, delta * fov_speed)

# -------------------------
# RECOIL
# -------------------------
func handle_recoil(delta: float) -> void:
	recoil_pos_vel += (-recoil_pos * recoil_spring) * delta
	recoil_rot_vel += (-recoil_rot * recoil_spring) * delta

	recoil_pos_vel *= 1.0 - recoil_damping * delta
	recoil_rot_vel *= 1.0 - recoil_damping * delta

	recoil_pos += recoil_pos_vel * delta
	recoil_rot += recoil_rot_vel * delta

func add_recoil(force: float) -> void:
	recoil_pos_vel -= recoil_kickback * force
	recoil_rot_vel += deg_to_rad(recoil_tilt * force)

# -------------------------
# HIT SHAKE TRIGGER
# -------------------------
func play_hit_shake(strength: float = 0.15, duration: float = 0.15) -> void:
	hit_shake_strength = strength
	hit_shake_duration = duration
	hit_shake_timer = duration

# -------------------------
# HIT SHAKE HANDLER
# -------------------------
func handle_hit_shake(delta: float) -> void:
	if hit_shake_timer > 0.0:
		hit_shake_timer -= delta

		var shake_offset = Vector3(
			randf_range(-hit_shake_strength, hit_shake_strength),
			randf_range(-hit_shake_strength, hit_shake_strength),
			randf_range(-hit_shake_strength, hit_shake_strength)
		)

		position = base_position + Vector3(0,0,recoil_pos) + shake_offset
		rotation = base_rotation + Vector3(recoil_rot,0,0)

# -------------------------
# QUICK SHOOT SHAKE
# -------------------------
func handle_quick_shoot_shake(delta: float) -> void:

	if hit_shake_timer > 0.0:
		return

	if shoot_shake_timer > 0.0:
		shoot_shake_timer -= delta

		var shake_offset = Vector3(
			randf_range(-shoot_shake_strength, shoot_shake_strength),
			randf_range(-shoot_shake_strength, shoot_shake_strength),
			randf_range(-shoot_shake_strength, shoot_shake_strength)
		)

		position = base_position + Vector3(0,0,recoil_pos) + shake_offset
	else:
		position = base_position + Vector3(0,0,recoil_pos)

	rotation = base_rotation + Vector3(recoil_rot,0,0)

# -------------------------
# OBJECT HANDLING
# -------------------------
func spawn_duplicate(original : RigidBody3D) -> void:
	aim_rotation.transform = aim_transform
	spawn_position.transform = spawn_transform

	object_to_shoot = original.duplicate()
	object_to_shoot.rotation = Vector3.ZERO

	spawn_position.add_child(object_to_shoot)

	object_to_shoot.global_position = spawn_position.global_position + Vector3.DOWN * 0.1
	object_to_shoot.freeze = true

	var tween = create_tween()
	tween.tween_property(object_to_shoot, "global_position", spawn_position.global_position, 0.1)

func delete_object_to_shoot() -> void:
	if object_to_shoot:
		var tween = create_tween()
		tween.tween_property(object_to_shoot, "global_position",
			spawn_position.global_position + Vector3.DOWN * 0.1, 0.1)

		await tween.finished
		object_to_shoot.queue_free()
		object_to_shoot = null

func charge() -> void:
	if not object_to_shoot:
		return

	charging = true
	charge_duration = 0
	rotated_fast = false

# -------------------------
# AIM ROTATION
# -------------------------
func handle_object_aim_rotation(delta: float) -> void:
	spawn_position.rotate_z(charge_duration / 5)

	charge_duration += delta
	charge_duration = clamp(charge_duration,0,2)

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

	GlobalManager.dispensor_selector.update_rotation(charge_duration)

# -------------------------
# SHOOT
# -------------------------
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

	# -------------------------
	# calculate applied force
	# -------------------------
	var applied_force = target_position - object_to_shoot.global_position
	applied_force += applied_force * charge_duration
	applied_force *= shoot_strength

	# -------------------------
	# add slight upward arc
	# -------------------------
	applied_force.y += applied_force.length() * throw_arc

	# -------------------------
	# optional random spin
	# -------------------------
	object_to_shoot.angular_velocity = Vector3(
		randf_range(-1.5,1.5),
		randf_range(-1.5,1.5),
		randf_range(-1.5,1.5)
	)

	object_to_shoot.apply_central_impulse(applied_force)

	add_recoil(1.0 + charge_duration)
	shoot_shake_timer = shoot_shake_duration

	object_to_shoot = null
	charge_duration = 0
	rotated_fast = false
	charging = false

	GlobalManager.dispensor_selector.shoot_from_dispenser()
	GlobalManager.cursor_body.last_dragged_object = null
