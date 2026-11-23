class_name WorldView
extends Camera3D

@onready var aim_rotation = $AimRotation
@onready var aim_transform = aim_rotation.transform
@onready var spawn_position = $AimRotation/SpawnPosition
@onready var spawn_transform = spawn_position.transform
@onready var hands : ShootingHands = $ShootingHands

@export var spawn_shootable : PackedScene
## Gradients and corners shown over the view while an item is in the hands.
@export var aim_frame_scene : PackedScene = preload("res://Prefabs/aim_frame.tscn")
## Size of the item in the hands, compared to its size in the automat.
@export var spawn_scale : float = 1.2

# -------------------------
# CHARGE (holding the mouse button)
# -------------------------
@export_group("Charge")
## The charge stops growing here. Time to full charge = Max Charge Duration / Charge Speed.
@export var max_charge_duration : float = 2.0
## How fast the charge grows.
@export var charge_speed : float = 1.0

@export_subgroup("Zoom")
## Field of view with nothing charging.
@export var normal_fov : float = 70.0
## Field of view at full charge. Lower = zooms in, higher = zooms out.
@export var charge_fov : float = 55.0
## How quickly the view follows the zoom. Higher = snappier.
@export var fov_speed : float = 6.0

@export_subgroup("Item in hands")
## How fast the item spins while charging, growing with the charge. 0 = no spin.
@export var charge_spin : float = 12.0
## At this much charge (0..1) the item flips forward, ready to throw. Above 1 = never.
@export_range(0.0, 1.1, 0.05) var charge_flip_at : float = 0.5
## How far the item flips, in degrees.
@export var charge_flip_angle : float = 90.0
## How long the flip takes, in seconds.
@export var charge_flip_time : float = 1.0
## How quickly the item turns to face the mouse. Higher = snappier.
@export var aim_follow_speed : float = 2.0

# -------------------------
# SHOT (releasing the mouse button)
# -------------------------
@export_group("Shot")
## Throw power with no charge; full charge doubles it.
@export var shoot_strength : float = 8.0
## Extra upward push, as a fraction of the power.
@export var throw_arc : float = 0.25

@export_subgroup("Recoil")
## How far the camera kicks back. Grows with the charge.
@export var recoil_kickback : float = 0.35
## How far the camera tilts up, in degrees. Grows with the charge.
@export var recoil_tilt : float = 3.0
## How hard the camera springs back. Higher = faster return.
@export var recoil_spring : float = 14.0
## How quickly the recoil wobble dies down. Higher = less wobble.
@export var recoil_damping : float = 10.0

@export_subgroup("Shake")
@export var shoot_shake_duration : float = 0.08
@export var shoot_shake_strength : float = 0.1

@export_subgroup("Particles")
@export var shoot_particles_root : Node3D
@export var shoot_particles_delay : float = 0.0
@export_group("")

var recoil_pos : float = 0.0
var recoil_pos_vel : float = 0.0
var recoil_rot : float = 0.0
var recoil_rot_vel : float = 0.0
var shoot_shake_timer : float = 0.0

# -------------------------
# MOUSE TILT
# -------------------------
@export_group("Mouse tilt")
@export var tilt_max_angle : float = 2.0
@export var tilt_smooth_speed : float = 5.0

var tilt : Vector3 = Vector3.ZERO

# -------------------------
# HIT SHAKE
# -------------------------
@export_group("Hit shake")
## How the hit shake fades out (x: 0 = shake start, 1 = shake end, y: strength).
## Empty = fades out smoothly.
@export var shake_curve : Curve
## Tilts the camera too: degrees of roll at shake strength 0.1. 0 = no roll.
@export var hit_shake_roll : float = 1.5
## Keeps shaking at full speed while a hitstop slows the game down.
@export var hit_shake_ignores_time_scale : bool = true
@export_group("")

var hit_shake_timer : float = 0.0
var hit_shake_duration : float = 0.15
var hit_shake_strength : float = 0.15
var hit_shake_frequency : float = 25.0
var hit_shake_time : float = 0.0
var hit_shake_offset : Vector3
var hit_shake_rotation : float = 0.0
var hit_shake_noise := FastNoiseLite.new()
var last_frame_usec : int = 0

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
## The slot item that object_to_shoot is a copy of. Hidden while it's in the hands.
var loaded_item : RandomItem
var throw_in_flight : bool = false
var held_scale : Vector3
var load_tween : Tween
var held_item_view : HeldItemView

# -------------------------
# LOAD FEEL
# -------------------------
@export_group("Load (item dropped into the hands)")
@export var load_time : float = 0.22
## Size of the item at the drop point, compared to its size in the hands.
@export var load_start_scale : float = 0.35
@export var load_squash : float = 0.08
@export var load_shake : float = 0.004
## How long after a shot items can't be picked up.
@export var throw_lock_time : float = 0.4
@export_group("")

# -------------------------
# READY
# -------------------------
func _ready() -> void:
	GlobalManager.world_view = self
	fov = normal_fov
	base_position = position
	base_rotation = rotation
	hit_shake_noise.frequency = 1.0
	hit_shake_noise.fractal_type = FastNoiseLite.FRACTAL_NONE

	# The held item is drawn by its own view on top, dithered while aiming.
	cull_mask &= ~HeldItemView.layer_bit()
	held_item_view = HeldItemView.new(self)
	_add_held_item_view.call_deferred()

	# Force all shoot particles to run in world space
	if shoot_particles_root:
		_set_particles_world_space(shoot_particles_root)

## Goes under the vignette and other screen overlays, so they cover the item too.
## Listed bottom to top: the aim frame's darkening and gradients go under the held item,
## so the item keeps its own colours.
func _add_held_item_view() -> void:
	var main_viewport := get_viewport()
	var overlays : Array[Node] = []
	if aim_frame_scene:
		overlays.append(aim_frame_scene.instantiate())
	overlays.append(held_item_view)
	for child in main_viewport.get_children():
		if child is CanvasItem:
			main_viewport.add_child(overlays[0])
			main_viewport.move_child(overlays[0], child.get_index())
			for i in range(1, overlays.size()):
				main_viewport.add_child(overlays[i])
				main_viewport.move_child(overlays[i], overlays[i - 1].get_index() + 1)
			return
	for overlay in overlays:
		main_viewport.add_child(overlay)

# -------------------------
# INPUT
# -------------------------
func _input(event) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
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
	handle_tilt(delta)
	handle_hit_shake(real_delta() if hit_shake_ignores_time_scale else delta)
	handle_quick_shoot_shake(delta)

	if charging:
		handle_object_aim_rotation(delta)

# -------------------------
# FOV
# -------------------------
func handle_fov(delta: float) -> void:
	var target_fov = normal_fov
	if charging:
		var charge_ratio = clamp(charge_duration / max_charge_duration, 0.0, 1.0)
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
# MOUSE TILT
# -------------------------
func handle_tilt(delta: float) -> void:
	var target_tilt := Vector3.ZERO
	var mouse_in_view = get_mouse_in_view()
	if mouse_in_view != null:
		var offset : Vector2 = mouse_in_view / Vector2(get_viewport().size) - Vector2(0.5, 0.5)
		target_tilt = Vector3(-offset.y, -offset.x, 0.0) * deg_to_rad(tilt_max_angle)
	tilt = tilt.lerp(target_tilt, delta * tilt_smooth_speed)

# -------------------------
# HIT SHAKE
# -------------------------
## strength: how far the camera moves. duration: real seconds.
## frequency: wiggles per second. A weaker shake won't cut off a stronger one.
func play_hit_shake(strength: float = 0.15, duration: float = 0.15, frequency: float = 25.0) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	if strength < current_hit_shake_strength():
		return
	hit_shake_strength = strength
	hit_shake_duration = duration
	hit_shake_timer = duration
	hit_shake_frequency = frequency
	hit_shake_noise.seed = randi()

func current_hit_shake_strength() -> float:
	if hit_shake_timer <= 0.0:
		return 0.0
	var progress := 1.0 - hit_shake_timer / hit_shake_duration
	if shake_curve:
		return hit_shake_strength * shake_curve.sample(progress)
	# Stays strong for most of the shake, then drops off at the end.
	return hit_shake_strength * (1.0 - progress * progress)

## Time since the last frame, ignoring Engine.time_scale (so it runs during hitstop).
func real_delta() -> float:
	var now := Time.get_ticks_usec()
	var delta := 0.0 if last_frame_usec == 0 else (now - last_frame_usec) / 1000000.0
	last_frame_usec = now
	return minf(delta, 0.1)

func handle_hit_shake(delta: float) -> void:
	if hit_shake_timer <= 0.0:
		hit_shake_offset = Vector3.ZERO
		hit_shake_rotation = 0.0
		return
	hit_shake_timer = maxf(hit_shake_timer - delta, 0.0)
	hit_shake_time += delta

	# Smooth noise instead of a new random spot every frame, so the shake looks
	# the same at any frame rate and the frequency is adjustable.
	# Raw noise mostly sits well inside -1..1, so boost it and clamp: the camera
	# then moves up to `strength` units, like the old random shake did.
	var strength := current_hit_shake_strength()
	var t := hit_shake_time * hit_shake_frequency
	hit_shake_offset = Vector3(
		shake_noise(t, 0.0),
		shake_noise(t, 100.0),
		0.0
	) * strength
	hit_shake_rotation = shake_noise(t, 200.0) * deg_to_rad(hit_shake_roll) * strength * 10.0

func shake_noise(t: float, lane: float) -> float:
	return clampf(hit_shake_noise.get_noise_2d(t, lane) * 2.5, -1.0, 1.0)

# -------------------------
# QUICK SHOOT SHAKE
# -------------------------
func handle_quick_shoot_shake(delta: float) -> void:
	var shake_offset := Vector3.ZERO
	if shoot_shake_timer > 0.0:
		shoot_shake_timer -= delta
		shake_offset = Vector3(
			randf_range(-shoot_shake_strength, shoot_shake_strength),
			randf_range(-shoot_shake_strength, shoot_shake_strength),
			randf_range(-shoot_shake_strength, shoot_shake_strength)
		)
	position = base_position + Vector3(0,0,recoil_pos) + shake_offset + hit_shake_offset
	rotation = base_rotation + Vector3(recoil_rot,0,hit_shake_rotation) + tilt

# -------------------------
# PARTICLES (WORLD SPACE)
# -------------------------
func play_shoot_particles(normalized_charge: float) -> void:
	if shoot_particles_root == null:
		return

	if shoot_particles_delay > 0.0:
		await get_tree().create_timer(shoot_particles_delay).timeout

	_restart_particles_recursive(shoot_particles_root)

func _restart_particles_recursive(node: Node) -> void:
	if node is CPUParticles3D or node is GPUParticles3D:
		node.restart()
	for c in node.get_children():
		_restart_particles_recursive(c)

func _set_particles_world_space(node: Node) -> void:
	if node is CPUParticles3D or node is GPUParticles3D:
		node.local_coords = false
	for c in node.get_children():
		_set_particles_world_space(c)

# -------------------------
# OBJECT HANDLING
# -------------------------
## The mouse position in this view's pixels, or null when it's outside the view.
func get_mouse_in_view() -> Variant:
	var container := get_viewport().get_parent() as SubViewportContainer
	var local_position := container.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, container.size).has_point(local_position):
		return null
	return local_position * Vector2(get_viewport().size) / container.size

## Puts the item in the hands, ready to charge and shoot.
func load_item(item : RandomItem, drop_position : Vector2) -> void:
	put_back_loaded_item()
	spawn_duplicate(item, drop_position)
	loaded_item = item
	loaded_item.visible = false

func put_back_loaded_item() -> void:
	if loaded_item == null:
		return
	loaded_item.visible = true
	loaded_item = null
	_stop_load_tween()
	delete_object_to_shoot()

func _stop_load_tween() -> void:
	if load_tween:
		load_tween.kill()
		load_tween = null

func spawn_duplicate(original : RigidBody3D, drop_position : Vector2) -> void:
	aim_rotation.transform = aim_transform
	spawn_position.transform = spawn_transform
	spawn_position.position.y += hands.item_rest_height

	object_to_shoot = original.duplicate()
	object_to_shoot.rotation = Vector3.ZERO
	spawn_position.add_child(object_to_shoot)
	held_item_view.hold(object_to_shoot)

	held_scale = object_to_shoot.scale * spawn_scale
	object_to_shoot.scale = held_scale * load_start_scale
	object_to_shoot.freeze = true
	object_to_shoot.global_position = project_position(drop_position, -to_local(spawn_position.global_position).z)

	# Falls from the drop point into the hands, then squashes on landing.
	load_tween = create_tween().set_parallel(true)
	load_tween.tween_property(object_to_shoot, "position", Vector3.ZERO, load_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	load_tween.tween_property(object_to_shoot, "scale", held_scale, load_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	load_tween.chain().tween_callback(_on_item_landed)
	load_tween.chain().tween_property(object_to_shoot, "scale", held_scale * Vector3(1.0 + load_squash, 1.0 - load_squash, 1.0 + load_squash), 0.05)
	load_tween.chain().tween_property(object_to_shoot, "scale", held_scale, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_item_landed() -> void:
	hands.catch_item()
	play_hit_shake(load_shake, 0.1)

func delete_object_to_shoot() -> void:
	if object_to_shoot:
		var object_to_delete = object_to_shoot
		object_to_shoot = null
		var tween = create_tween()
		tween.tween_property(
			object_to_delete,
			"global_position",
			spawn_position.global_position + Vector3.DOWN * 0.1,
			0.1
		)
		await tween.finished
		object_to_delete.queue_free()

# -------------------------
# CHARGING
# -------------------------
func charge() -> void:
	if not object_to_shoot or GlobalManager.cursor_body.in_dialogue:
		return
	charging = true
	charge_duration = 0
	rotated_fast = false

# -------------------------
# AIM ROTATION
# -------------------------
func handle_object_aim_rotation(delta: float) -> void:
	spawn_position.rotate_z(charge_duration * charge_spin * delta)
	charge_duration += delta * charge_speed
	charge_duration = clamp(charge_duration, 0, max_charge_duration)

	var direction = project_ray_normal(screen_position)
	var target_basis = Basis.looking_at(direction, Vector3.UP)
	var current_quat = aim_rotation.basis.get_rotation_quaternion()
	var target_quat = target_basis.get_rotation_quaternion()
	var new_quat = current_quat.slerp(target_quat, clamp(delta * aim_follow_speed, 0.0, 1.0))
	aim_rotation.transform.basis = Basis(new_quat)

	if not rotated_fast and charge_duration > max_charge_duration * charge_flip_at:
		rotate_object_tween = get_tree().create_tween()
		rotate_object_tween.tween_property(object_to_shoot, "rotation", Vector3(deg_to_rad(charge_flip_angle), 0, 0), charge_flip_time)
		rotated_fast = true

# -------------------------
# SHOOT
# -------------------------
func shoot(mouse_position : Vector2) -> void:
	if object_to_shoot == null or not charging:
		return
	if rotate_object_tween != null:
		rotate_object_tween.stop()
	_stop_load_tween()
	object_to_shoot.position = Vector3.ZERO
	object_to_shoot.scale = held_scale

	var from = project_ray_origin(mouse_position)
	var direction = project_ray_normal(mouse_position) * 2
	var target_position = from + direction

	object_to_shoot.reparent(get_parent())
	object_to_shoot.freeze = false
	held_item_view.release(object_to_shoot)

	var normalized_charge = charge_duration / max_charge_duration
	var power = shoot_strength * (1.0 + normalized_charge)

	var applied_force = (target_position - object_to_shoot.global_position).normalized() * power
	applied_force.y += power * throw_arc

	object_to_shoot.angular_velocity = Vector3(
		randf_range(-1.5,1.5),
		randf_range(-1.5,1.5),
		randf_range(-1.5,1.5)
	)
	object_to_shoot.apply_central_impulse(applied_force)

	add_recoil(1.0 + normalized_charge)
	shoot_shake_timer = shoot_shake_duration
	hands.throw_item()

	# 🔥 PARTICLES (WORLD SPACE)
	play_shoot_particles(normalized_charge)

	object_to_shoot = null
	charge_duration = 0
	rotated_fast = false
	charging = false

	loaded_item.visible = true
	loaded_item = null
	GlobalManager.cursor_body.last_dragged_object = null

	throw_in_flight = true
	await get_tree().create_timer(throw_lock_time).timeout
	throw_in_flight = false
