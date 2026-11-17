class_name RandomPerson
extends Node3D

@export var person_name: String
## When set, its id replaces person_name.
@export var character: CharacterData
@export var hit_particles: CPUParticles3D
@export var hitstop_duration: float = 0.05
@export var hitstop_scale: float = 0.01
@export var visual: Sprite3D

# Hit sound pitch variation
@export var min_hit_pitch: float = 0.92
@export var max_hit_pitch: float = 1.08

@onready var rigidbody: RigidBody3D = $RigidBody3D
@onready var hit_sound: AudioStreamPlayer = $HitSound

# Hit cooldown
@export var hit_cooldown: float = 0.5
var can_be_hit: bool = true

# Squish while talking
## How much the visual flattens on each squish. 0.15 = 15% shorter and wider.
@export var squish_amount: float = 0.15
## How long one squish takes, in seconds.
@export var squish_time: float = 0.25
## The sprite that squishes. Empty = the visual, or the first visible sprite
## on the RigidBody3D when the visual is hidden (e.g. an AnimatedSprite3D).
@export var squish_target: SpriteBase3D
var squish_tween: Tween
var squish_value := 0.0
var squish_start_scale: Vector3
var squish_start_position: Vector3

func _ready() -> void:
	if character:
		person_name = character.id

	# Register this character
	if person_name != "":
		GlobalManager.characters[person_name] = self
	else:
		print("WARNING: person_name is empty!")

	rigidbody.contact_monitor = true
	rigidbody.max_contacts_reported = 1
	rigidbody.body_entered.connect(body_entered)

	setup_material()

	if squish_target == null:
		squish_target = find_squish_target()
	if squish_target:
		squish_start_scale = squish_target.scale
		squish_start_position = squish_target.position

# -----------------------------
# SQUISH (TALKING)
# -----------------------------
func find_squish_target() -> SpriteBase3D:
	if visual and visual.visible and visual.texture:
		return visual
	for child in rigidbody.get_children():
		if child is SpriteBase3D and child.visible:
			return child
	return null

func squish() -> void:
	if squish_target == null or squish_time <= 0.0:
		return

	if squish_tween:
		squish_tween.kill()

	squish_tween = create_tween()
	squish_tween.tween_method(set_squish, squish_value, 1.0, squish_time * 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	squish_tween.tween_method(set_squish, 1.0, 0.0, squish_time * 0.7)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_squish(value: float) -> void:
	squish_value = value
	var amount := squish_amount * value
	squish_target.scale = squish_start_scale * Vector3(1.0 + amount, 1.0 - amount, 1.0)

	# Keep the feet on the ground while squished
	var bottom := squish_target.get_aabb().position.y
	squish_target.position.y = squish_start_position.y + squish_start_scale.y * amount * bottom

# -----------------------------
# SETUP MATERIAL
# -----------------------------
func setup_material() -> void:
	if visual == null:
		return
	
	if visual.material_override:
		# Make material unique per instance
		visual.material_override = visual.material_override.duplicate()
	
	var mat := visual.material_override as ShaderMaterial
	if mat == null:
		return
	
	# Assign the correct texture automatically
	mat.set_shader_parameter("tex", visual.texture)

# -----------------------------
# HIT DETECTION
# -----------------------------
func body_entered(body: Node) -> void:
	if not can_be_hit:
		return
	
	if body is RandomItem:
		var item: RandomItem = body
		
		# Register hit
		item.hit_speed = item.linear_velocity.length()
		GlobalManager.item_that_hit = item
		
		# Trigger dialogue
		GlobalManager.scene_dialogue_manager.character_hit(person_name, item)

		# Camera shake
		if GlobalManager.world_view:
			GlobalManager.world_view.play_hit_shake(0.25, 0.2)

		# Sound
		play_hit_sound()

		# Effects
		play_hit_particles()
		flash_white()

		# Systems
		start_hit_cooldown()
		apply_hitstop()

# -----------------------------
# SOUND
# -----------------------------
func play_hit_sound() -> void:
	if hit_sound:
		hit_sound.pitch_scale = randf_range(
			min_hit_pitch,
			max_hit_pitch
		)
		hit_sound.stop()
		hit_sound.play()

# -----------------------------
# FLASH (SHADER)
# -----------------------------
func flash_white() -> void:
	if visual == null:
		return
	
	var mat := visual.material_override as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("active", true)

	await get_tree().create_timer(0.05).timeout

	mat.set_shader_parameter("active", false)

# -----------------------------
# COOLDOWN
# -----------------------------
func start_hit_cooldown() -> void:
	can_be_hit = false

	var t := Timer.new()
	t.one_shot = true
	t.wait_time = hit_cooldown

	add_child(t)
	t.start()

	await t.timeout

	t.queue_free()
	can_be_hit = true

# -----------------------------
# PARTICLES
# -----------------------------
func play_hit_particles() -> void:
	if hit_particles:
		hit_particles.restart()

# -----------------------------
# HITSTOP
# -----------------------------
func apply_hitstop() -> void:
	var original_time_scale = Engine.time_scale

	Engine.time_scale = hitstop_scale

	var t := Timer.new()
	t.one_shot = true
	t.wait_time = hitstop_duration

	add_child(t)
	t.start()

	await t.timeout

	t.queue_free()

	Engine.time_scale = original_time_scale
