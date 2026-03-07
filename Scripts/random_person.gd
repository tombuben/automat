class_name RandomPerson extends Node3D

@export var person_name : String
@onready var rigidbody = $RigidBody3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	rigidbody.contact_monitor = true
	rigidbody.max_contacts_reported = 1
	rigidbody.body_entered.connect(body_entered)

# Called every frame.
func _process(delta: float) -> void:
	pass

func body_entered(body: Node):
	if body is RandomItem:
		var item = body as RandomItem
		
		print(item.item_name)

		GlobalManager.item_that_hit = item
		GlobalManager.scene_dialogue_manager.show_dialogue(person_name + "_hit")

		# Trigger camera hit shake
		if GlobalManager.world_view:
			GlobalManager.world_view.play_hit_shake(0.25, 0.2)
