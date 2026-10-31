class_name InteractPrompt3D
extends StaticBody3D
# =====================================================
# IN-WORLD INTERACT PROMPT
# =====================================================
# A clickable 3D icon/prop, placed and sized by hand in the editor for
# each interactable. Detected by ClickToMove's existing raycast (via the
# "interactable_prompt" group) rather than any 2D UI system — clicking
# it fires on_prompt_clicked() instead of walking the player there.
#
# Expected scene structure (children of this StaticBody3D):
#   - CollisionShape3D — sized/shaped to match however big you want the
#     clickable area to be (can be bigger than the visual for an easier
#     target, same as a UI hit-box padding).
#   - Any visual you like: MeshInstance3D, Sprite3D, an animated icon,
#     whatever fits the scene. Give it a billboard mode if you want it
#     to always face the camera.
#
# This node is a StaticBody3D (not Area3D) specifically so it's hit by
# ClickToMove's raycast without needing collide_with_areas enabled there
# — a plain physics raycast already hits StaticBody3D colliders.
@export var interactable: Node # the Interactable that owns this prompt; defaults to get_parent()
func _ready():
	add_to_group("interactable_prompt")
	if interactable == null:
		interactable = get_parent()
	hide_prompt()
func show_prompt() -> void:
	visible = true
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = false
func hide_prompt() -> void:
	visible = false
	for child in get_children():
		if child is CollisionShape3D:
			child.disabled = true
# Called by ClickToMove when a click raycast hits this node.
func on_prompt_clicked() -> void:
	if interactable and interactable.has_method("trigger"):
		interactable.trigger()
