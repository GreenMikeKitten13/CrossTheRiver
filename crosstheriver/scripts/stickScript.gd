extends RigidBody3D

@onready var gravity:float = ProjectSettings.get_setting("physics/3d/default_gravity")

const testInStick = preload("res://scenes/testInStick.tscn")
var waterLevel:float = 1.0
var waterDensity:float = 1.0
var timer:float = 0.0
var points:Array[Vector3] = []

func _physics_process(delta: float) -> void:
	timer += delta
	if timer >= 0.1:
		#self.linear_velocity.y = 0.25
		points = []
		for child:Node3D in self.get_children():
			if child is MeshInstance3D and child.mesh is CylinderMesh:
				#if child.name.begins_with("bup"):
				#	child.queue_free()
				var childPos = self.to_local(child.global_transform.origin)
				var rotation_euler: Vector3 = child.rotation
				var quat = Quaternion()
				quat = Quaternion.from_euler(rotation_euler)
				var sasis = Basis(quat)
				var child_transform = Transform3D(sasis, childPos)

				for i in range(10):
					var local_point = get_random_point_in_cylinder(child.mesh.top_radius, child.mesh.height)
					var global_point = child_transform * local_point  # use * instead of xform
					points.append(global_point)
	
				var submergedPoints:Array[Vector3]
				for point:Vector3 in points:
					if point.y <= waterLevel:
						submergedPoints.append(point)
				
				var submergedVolume = submerged_volume(submergedPoints.size(), points.size(), child.mesh.top_radius, child.mesh.height)
				var middlePoint:Vector3 = Vector3.ZERO
				for submergedPoint:Vector3 in submergedPoints:
					middlePoint += submergedPoint
				middlePoint /= submergedPoints.size()
				var force = (waterDensity * gravity * submergedVolume)
				self.apply_impulse(Vector3(0,force, 0), middlePoint)

func get_random_point_in_cylinder(radius: float, height: float) -> Vector3:
	var angle = randf() * TAU
	var r = sqrt(randf()) * radius
	var x = r * cos(angle)
	var z = r * sin(angle)
	var y = randf() * height - height * 0.5
	return Vector3(x, y, z)

func submerged_volume(submerged_samples: int, total_samples: int, radius: float, height: float) -> float:
	var ratio = float(submerged_samples) / float(total_samples)
	var full_volume = PI * radius * radius * height
	return ratio * full_volume
