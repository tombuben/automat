class_name RandomPerson
extends Node3D

@export var person_name: String
@export var hit_particles: CPUParticles3D
@export var hitstop_duration: float = 0.05
@export var hitstop_scale: float = 0.01
@export var visual: Sprite3D  # assign this in the Inspector

@onready var rigidbody: RigidBody3D = $RigidBody3D

# Hit cooldown
@export var hit_cooldown: float = 0.5
var can_be_hit: bool = true

func _ready() -> void:
	# ✅ REGISTER THIS CHARACTER FOR ANIMATION SYSTEM
	if person_name != "":
		GlobalManager.characters[person_name] = self
	else:
		print("WARNING: person_name is empty!")

	rigidbody.contact_monitor = true
	rigidbody.max_contacts_reported = 1
	rigidbody.body_entered.connect(body_entered)

	setup_material()

# -----------------------------
# SETUP MATERIAL (IMPORTANT)
# -----------------------------
func setup_material():
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
		var item: RandomItem = body as RandomItem
		
		# Register hit
		item.hit_speed = item.linear_velocity.length()
		GlobalManager.item_that_hit = item
		
		# Trigger dialogue (unchanged)
		GlobalManager.scene_dialogue_manager.show_dialogue(person_name + "_hit")

		# Camera hit shake
		if GlobalManager.world_view:
			GlobalManager.world_view.play_hit_shake(0.25, 0.2)

		# Effects
		play_hit_particles()
		flash_white()

		# Systems
		start_hit_cooldown()
		apply_hitstop()

# -----------------------------
# FLASH (SHADER)
# -----------------------------
func flash_white():
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
	var t: Timer = Timer.new()
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
	
	var t: Timer = Timer.new()
	t.one_shot = true
	t.wait_time = hitstop_duration
	add_child(t)
	t.start()
	await t.timeout
	t.queue_free()
	
	Engine.time_scale = original_time_scale
