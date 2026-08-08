@tool
extends Sprite2D

@export var r_vec: Vector2 = Vector2.RIGHT:
	set(val):
		r_vec = val
		if val != Vector2.ZERO:
			rotation = val.angle()
