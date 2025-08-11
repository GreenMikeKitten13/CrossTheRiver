extends Node3D

func _process(delta: float) -> void:
	self.rotate(Vector3.UP, 1 * delta)
