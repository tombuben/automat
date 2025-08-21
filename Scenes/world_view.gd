extends Camera3D

@onready var spawn_position = $SpawnPosition
@export var spawnItem : PackedScene

func _input(event) -> void:
	# Mouse in viewport coordinates.
	if event is InputEventMouseButton:
		var relative_position = event.position / get_viewport().get_visible_rect().size.y
		relative_position.x = (relative_position.x * 2) - 1
		relative_position.y = (relative_position.y * 2) - 1
		print("Mouse Click/Unclick at: ", relative_position)
		
		var relative_angle = relative_position * fov/2
		print("Mouse Click/Unclick at: ", relative_angle)

		#todo check left right mouse button :)
		if event.is_pressed():
			charge()
		if event.is_released():
			shoot(relative_angle)
	elif event is InputEventMouseMotion:
		print("Mouse Motion at: ", event.position)

	# Print the size of the viewport.
	print("Viewport Resolution is: ", get_viewport().get_visible_rect().size)


var object_to_shoot : RigidBody3D
var charge_duration : float
var rotated_fast : bool
var tween : Tween

func charge() -> void:
	if object_to_shoot != null:
		return
	object_to_shoot = spawnItem.instantiate()
	spawn_position.add_child(object_to_shoot)
	object_to_shoot.freeze = true
	charge_duration = 0
	rotated_fast = false
	
	
func _process(delta: float) -> void:
	if object_to_shoot != null:
		spawn_position.rotate_z(charge_duration / 5)
		charge_duration += delta
		
		if rotated_fast == false and charge_duration > 1:
			tween = get_tree().create_tween()
			
			var target_rotation = Vector3(
				deg_to_rad(90),
				deg_to_rad(0),
				deg_to_rad(0)
			)
			
			tween.tween_property(object_to_shoot, "rotation", target_rotation, 1)
			rotated_fast = true

func shoot(relative_angle) -> void:
	if object_to_shoot == null:
		return
	
	tween.stop()
	object_to_shoot.reparent(self)
	object_to_shoot.freeze = false
	var applied_force = transform.basis.z * (-charge_duration * 5 - 1) + transform.basis.y * 3
	
	applied_force = applied_force.rotated(-transform.basis.y, deg_to_rad(relative_angle.x))
	
	# i shouldn't rotate this by this horizon, i should push the applied force vector up and down
	applied_force = applied_force.rotated(-transform.basis.x, deg_to_rad(relative_angle.y))
	object_to_shoot.apply_central_impulse(applied_force)
	object_to_shoot = null
	charge_duration = 0
	rotated_fast = false
