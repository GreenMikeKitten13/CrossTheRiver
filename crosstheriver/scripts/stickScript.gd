extends RigidBody3D

@onready var gravity:float = ProjectSettings.get_setting("physics/3d/default_gravity")

const testInStick = preload("res://scenes/testInStick.tscn")
var waterLevel:float = 0.0
var timer:float = 0.0
var points:Array[Vector3] = []

func _physics_process(delta: float) -> void:
	timer += delta
	if timer >= 0.1:
		points = []
		for child:Node3D in self.get_children():
			if child is MeshInstance3D and child.mesh is CylinderMesh:
				var childPos = self.to_local(child.global_transform.origin)
				var rotation_euler: Vector3 = child.rotation#childData[1]  # ensure radians
				#rotation_euler = Vector3(deg_to_rad(rotation_euler.x), deg_to_rad(rotation_euler.y), deg_to_rad(rotation_euler.z))
				var quat = Quaternion()
				quat = Quaternion.from_euler(rotation_euler)
				#Quaternion.from_euler(rotation_euler)
				var sasis = Basis(quat)
				var child_transform = Transform3D(sasis, childPos)

				for i in range(10):
					var local_point = get_random_point_in_cylinder(child.mesh.top_radius, child.mesh.height)
					var global_point = child_transform * local_point  # use * instead of xform
					points.append(global_point)
					
					#var test:MeshInstance3D = MeshInstance3D.new()
					#var testMesh:BoxMesh =  BoxMesh.new()
					#testMesh.size = Vector3(0.01, 0.01, 0.01 )
					#test.mesh =testMesh
					#test.position = global_point
					#self.add_child(test)


func get_random_point_in_cylinder(radius: float, height: float) -> Vector3:
	var angle = randf() * TAU
	var r = sqrt(randf()) * radius
	var x = r * cos(angle)
	var z = r * sin(angle)
	var y = randf() * height - height * 0.5
	return Vector3(x, y, z)
