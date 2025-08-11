extends  Node3D

var stickCount:int = 0

func _ready() -> void:
	for stickID:int in randi_range(4, 10):
		var stickBody:RigidBody3D = RigidBody3D.new()
		stickBody.name = "stick " + str(stickID)
		var stickPosition:Vector3 = Vector3(randf_range(-10, 10),randf_range(1, 5), randf_range(-10 ,10))
		stickBody.position = stickPosition
		var stickRotation:Vector3 = Vector3(0,0,0)
		var stickRadius:float = randf_range(0.05, 0.1)
		var stickHeight:float = randf_range(0.5, 1.5)
		var stickMaterial:StandardMaterial3D = StandardMaterial3D.new()
		stickMaterial.albedo_color = Color(randf_range(140, 255) / 255.0, randf_range(0, 80) / 255.0, randf_range(20, 80) / 255.0, 1)
		stickMaterial.emission_enabled = false
		createSitck(Vector3(0,0,0), stickRotation, stickRadius, stickHeight, stickBody)
		for branch in randi_range(0, 3):
			var branchPosition:Vector3 = Vector3(randf_range(-0.4, 0.4) * stickRadius, randf_range(-0.4, 0.4) * stickHeight, randf_range(0.4, 0.4) * stickRadius)  #(stickPosition + Vector3(randf_range(0.5, 2),randf_range(0.5, 1), randf_range(0.5 ,2)) )* stickRadius
			var branchRotation:Vector3 = Vector3(randf_range(-20, 20),randf_range(-20, 20), randf_range(-20 ,20))
			var branchRadius:float = max(stickRadius -randf_range(0.02, 0.1), 0.035)
			var branchHeight:float = max(stickHeight - randf_range(0.2, 0.4), 0.1)
			createSitck(branchPosition, branchRotation, branchRadius, branchHeight, stickBody)
		for child:Node3D in stickBody.get_children():
			if child is MeshInstance3D:
				child.mesh.material = stickMaterial
		stickBody.set_meta("stick", true)
		self.add_child(stickBody)


func createSitck(stickPosition:Vector3, stickRotation:Vector3, radius:float, height:float, parent:Node) -> void:
	var stick:MeshInstance3D = MeshInstance3D.new()
	var stickCollision:CollisionShape3D = CollisionShape3D.new()
	var stickProperties:CylinderMesh = CylinderMesh.new()
	var collisionShape:CylinderShape3D = CylinderShape3D.new()
	stickCount += 1
	
	stickProperties.top_radius = radius
	stickProperties.bottom_radius = radius
	stickProperties.height = height
	stick.position = stickPosition
	stick.rotation = stickRotation
	stick.name = "stickMesh " + str(stickCount)
	
	collisionShape.radius = radius
	collisionShape.height = height
	stickCollision.position = stickPosition
	stickCollision.rotation = stickRotation
	stickCollision.name = "stickCollision" + str(stickCount)
	
	stick.mesh = stickProperties
	stickCollision.shape = collisionShape
	
	
	parent.add_child(stick)
	parent.add_child(stickCollision)
