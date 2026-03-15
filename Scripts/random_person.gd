class_name RandomPerson extends Node3D

@export var person_name : String
@export var hit_cooldown := 0.5
@onready var rigidbody = $RigidBody3D

var can_be_hit := true

func _ready() -> void:
	rigidbody.contact_monitor = true
	rigidbody.max_contacts_reported = 1
	rigidbody.body_entered.connect(body_entered)


func body_entered(body: Node) -> void:
	if body is RandomItem and can_be_hit:
		var item = body as RandomItem
		
		# Register hit
		item.hit_speed = item.linear_velocity.length()
		GlobalManager.item_that_hit = item
		GlobalManager.scene_dialogue_manager.show_dialogue(person_name + "_hit")

		# Camera hit shake
		if GlobalManager.world_view:
			GlobalManager.world_view.play_hit_shake(0.25, 0.2)
		
		# Start cooldown
		can_be_hit = false
		start_hit_cooldown()


func start_hit_cooldown() -> void:
	var timer = Timer.new()
	timer.wait_time = hit_cooldown
	timer.one_shot = true
	add_child(timer)
	timer.start()
	await timer.timeout
	timer.queue_free()
	can_be_hit = true
