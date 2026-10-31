@tool
class_name ItemReaction extends Resource
## One row of an Encounter: an item, its preview, and what it leads to.

@export_enum("coffee_large", "coffee_medium", "rubber_duck", "moral_compass", "mind", "heart") var item : String = "coffee_large"
## Shown when hovering the item. The chapter adds the color.
@export_multiline var preview : String
## Title in the encounter's dialogue file. Empty = use "Any other item".
@export var dialogue_title : String
## Played on the character when hit. Empty = no animation.
@export var animation : String = "hit"
