extends RigidBody3D

@onready var gravity:float = ProjectSettings.get_setting("physics/3d/default_gravity")

const testInStick = preload("res://scenes/testInStick.tscn")
var waterLevel:float = 0.0


func _ready() -> void:
	print("works")
	var points:Array[Vector3] = []
