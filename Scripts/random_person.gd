class_name RandomPerson
extends Node3D

@export var person_name: String
@export var hit_particles: CPUParticles3D   # Assign in Inspector
@export var hitstop_duration: float = 0.05  # How long the hitstop lasts
@export var hitstop_scale: float = 0.01     # How slow the game goes during hitstop

@onready var rigidbody: RigidBody3D = $RigidBody3D
@onready var visual: Sprite3D = $Sprite3D

# Squash/stretch parameters
var squash_strength: float = 0.2
var squash_duration: float = 0.1
var recover_duration: float = 0.2

# Hit cooldown
@export var hit_cooldown: float = 0.5
var can_be_hit: bool = true

# Active tween for visual
var current_hit_tween: Tween = null

func _ready() -> void:
	rigidbody.contact_monitor = true
	rigidbody.max_contacts_reported = 1
	rigidbody.body_entered.connect(body_entered)

func body_entered(body: Node) -> void:
	if not can_be_hit:
		return
	
	if body is RandomItem:
		var item: RandomItem = body as RandomItem
		
		# Register hit
		item.hit_speed = item.linear_velocity.length()
		GlobalManager.item_that_hit = item
		GlobalManager.scene_dialogue_manager.show_dialogue(person_name + "_hit")

		# Camera hit shake
		if GlobalManager.world_view:
			GlobalManager.world_view.play_hit_shake(0.25, 0.2)

		# Play hit particles
		play_hit_particles()

		# Apply squash/stretch
		apply_squash_and_stretch(item.hit_speed)

		# Start hit cooldown
		start_hit_cooldown()

		# Apply hitstop
		apply_hitstop()

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

func play_hit_particles() -> void:
	if hit_particles:
		hit_particles.restart()

func apply_squash_and_stretch(hit_speed: float) -> void:
	if visual == null:
		return

	var strength: float = clamp(hit_speed * 0.05, 0.05, squash_strength)

	var target_scale: Vector3 = Vector3(
		1.0 + strength,
		1.0 - strength,
		1.0 + strength
	)

	# Kill previous tween
	if current_hit_tween != null and current_hit_tween.is_valid():
		current_hit_tween.kill()
		current_hit_tween.queue_free()

	# Create new tween
	current_hit_tween = visual.create_tween() as Tween
	current_hit_tween.tween_property(visual, "scale", target_scale, squash_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	current_hit_tween.tween_property(visual, "scale", Vector3.ONE, recover_duration)\
		.set_delay(squash_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	current_hit_tween.play()

# -----------------------------
# Hitstop
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
