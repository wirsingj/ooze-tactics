extends Node2D
class_name WorldRenderLayer

var controller: Node = null
var layer_kind: String = "background"

func _draw() -> void:
	if controller == null:
		return

	match layer_kind:
		"background":
			controller._draw_world_background(self)
		"slime":
			controller._draw_world_slime(self)
		"emissive":
			controller._draw_world_emissive(self)
		"overlay":
			controller._draw_world_overlay(self)
