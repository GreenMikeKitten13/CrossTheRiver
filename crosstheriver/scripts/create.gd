extends Node

var savePath = "user://inventory.tres"
var inventory = {}
@onready var  camera:Camera3D = Camera3D.new()
@onready var stickBody:RigidBody3D = RigidBody3D.new()
@onready var main_camera: Camera3D = %MainCamera

const stickPicture = preload("res://scenes/StickPicture.tscn")
const StickScript = preload("res://scripts/stickScript.gd")

func _ready() -> void:
	#var client = Nakama.create_client("defaultkey", "127.0.0.1", 7350, "http")
	#print("Nakama client created!")
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var lastLeftPosVec = Vector3(-50,-1,-27.5)
	var lastRightPosVec = Vector3(-50,-1,27.5)
	for LeftEdgeID:int in 2:
		var edge:StaticBody3D = $"../grass".duplicate()#rock_width, rock_height, noise_strength, roughness
		#edge.rotation = Vector3(0, randf_range(0, 40), 0)
		edge.position = lastLeftPosVec + Vector3(50,0,0) #* #LeftEdgeID
		lastLeftPosVec = edge.position
		self.get_parent().add_child.call_deferred(edge)
	
	for rightEdgeID:int in 2:
		var edge:StaticBody3D = $"../grass".duplicate()#rock_width, rock_height, noise_strength, roughness
		#edge.rotation = Vector3(0, randf_range(0, 40), 0)
		edge.position = lastRightPosVec + Vector3(50,0,0) #* #LeftEdgeID
		lastRightPosVec = edge.position
		self.get_parent().add_child.call_deferred(edge)
	
	var lastWaterPos:float
	for waterID:int in 4:
		var water:MeshInstance3D = $"../water".duplicate()
		water.position = Vector3(waterID * 25, -6, 0)
		if randf() <= 0.5 and not waterID == 0:
			water.position = Vector3(0, lastWaterPos -5,0)
			
		lastWaterPos = water.position.y
		self.get_parent().add_child.call_deferred(water)
	
	segments_circumference = 8
	
	for row:int in range(0, 50, randi_range(2, 6)):#(0, randi_range(6, 24), 3):
		for rockID:int in randi_range(0, 5):
			rock_length = randf_range(0.8,1.2) #1
			rock_width = randf_range(1.3,1.7)#1.5
			rock_height = randf_range(0.8, 1.2)
			taper_strength = 1.0
			segments_length = 14
			segments_circumference = 8
			noise_strength = randf_range(0.3, 0.7)#0.5
			roughness = randf_range(0.1,0.5)#0.3
			
			var stone:StaticBody3D = create_rock_staticbody(Vector3(row,-1,randf_range(-3, 3)))
			self.get_parent().add_child.call_deferred(stone)
			stone.rotate(Vector3.UP, 90)
	
	var inventoryData := ResourceLoader.load(savePath) as saveData
	if inventoryData:
		inventory.assign(inventoryData.inventory)
		#camera.current = true

		for stickName in inventory.keys():
			var stickData:Dictionary = inventory[stickName]
			var points:Array[Vector3] = []
			camera = Camera3D.new()
			
			#var stickBody:RigidBody3D = RigidBody3D.new()
			stickBody.set_script(StickScript)
			#print(stickBody.get_script())
			var stickMaterial:StandardMaterial3D = StandardMaterial3D.new()
			stickMaterial.albedo_color = stickData["color"]
			
			for neededChild:String in stickData["children"].keys():
				
				var childData = stickData["children"][neededChild]
				var stickCollider:CollisionShape3D = CollisionShape3D.new()
				var stickMesh:MeshInstance3D = MeshInstance3D.new()
				var stickMeshProperties:CylinderMesh = CylinderMesh.new()
				var stickColliderProperties:CylinderShape3D = CylinderShape3D.new()
	
				stickCollider.transform.origin = childData[0]#- stickData["position"]
				stickMesh.transform.origin = childData[0] #- stickData["position"]
				stickCollider.rotation = childData[1]
				stickMesh.rotation = childData[1]
				
				stickMeshProperties.bottom_radius = childData[2]
				stickMeshProperties.top_radius = childData[2]
				stickColliderProperties.radius = childData[2]
				
				stickMeshProperties.height = childData[3]
				stickColliderProperties.height = childData[3]
				
				stickMesh.mesh = stickMeshProperties
				stickCollider.shape = stickColliderProperties
				
				stickMeshProperties.material = stickMaterial
				stickBody.add_child(stickCollider)
				stickBody.add_child(stickMesh)


			var container:GridContainer = %inventory.get_child(0)
			var newStickPicture:SubViewportContainer = stickPicture.instantiate()
			var subViewPort:SubViewport = newStickPicture.get_child(0)
			var Buttton:Button = subViewPort.get_child(-1)
			Buttton.connect("pressed", addStick.bind(stickBody, container, subViewPort.find_child("CameraPivot")))

			subViewPort.add_child(stickBody)
			stickBody.position = Vector3.ZERO
			stickBody.freeze = true
			stickBody.set_meta("control", stickData["control"])
			stickBody.set_meta("speed", stickData["speed"])
			self.get_parent().add_child.call_deferred(camera)
			#print(camera.get_parent())
			
			#camera.reparent(self.get_parent())
			#print(camera.get_parent())
			#camera.position = Vector3(-2,5,0)
			#camera.get_child(-1).queue_free()

			stickBody.set_meta("points", points)
			stickBody = RigidBody3D.new()
			points = []

			container.add_child(newStickPicture)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(_delta: float) -> void:
	if  stickBody.position.x -  camera.position.x> 10:
		get_tree().create_tween().tween_property(main_camera, "position", stickBody.position + Vector3(-2,5,0), 3.0 )  #camera.position = stickBody.position + Vector3(-2,3,0)#Vector3.UP#
	main_camera.look_at(stickBody.position)

#extends Node3D

# Rock generation parameters
@export var rock_length: float = 1 #3
@export var rock_width: float = 1.5 #1.0
@export var rock_height: float = 1.0 # 0.8
@export var segments_length: int = 14 #12
@export var segments_circumference: int = 8
@export var noise_strength: float = 0.5 #0.3
@export var roughness: float =  0.3#1.0  #0.5
@export var randomness: float = 0.5 #0.2
@export var taper_strength: float = 1 #0.3  # How much the rock tapers at the ends

# Generated data
var rock_vertices: PackedVector3Array = []
var rock_indices: PackedInt32Array = []

func generate_rock() -> Dictionary:
	rock_vertices.clear()
	rock_indices.clear()
	
	# Generate base ellipsoid points and deform them into a rock shape
	generate_base_vertices()
	generate_indices()
	
	return {
		"vertices": rock_vertices,
		"indices": rock_indices
	}

func generate_base_vertices():
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 1.0
	noise.seed = randi()
	
	# Generate vertices in a roughly ellipsoidal pattern
	for i in range(segments_length + 1):
		var u = float(i) / float(segments_length)  # 0 to 1 along length
		var x = (u - 0.5) * rock_length
		
		# Calculate taper factor (narrower at ends)
		var taper = 1.0 - taper_strength * abs(2.0 * u - 1.0) * abs(2.0 * u - 1.0)
		
		for j in range(segments_circumference):
			var v = float(j) / float(segments_circumference)  # 0 to 1 around circumference
			var angle = v * TAU
			
			# Base ellipse calculation
			var y_base = cos(angle) * rock_height * 0.5 * taper
			var z_base = sin(angle) * rock_width * 0.5 * taper
			
			# Add noise for rock-like irregularities
			var noise_sample = noise.get_noise_3d(x * 2.0, y_base * 2.0, z_base * 2.0)
			var noise_factor = 1.0 + noise_sample * noise_strength
			
			# Add additional roughness
			var rough_x = x + randf_range(-randomness, randomness) * rock_length * 0.1
			var rough_y = y_base * noise_factor + randf_range(-roughness, roughness) * rock_height * 0.2
			var rough_z = z_base * noise_factor + randf_range(-roughness, roughness) * rock_width * 0.2
			
			# Add some bulges and indentations typical of rocks
			var bulge_noise = noise.get_noise_3d(rough_x * 0.5, rough_y * 0.5, rough_z * 0.5)
			var bulge_factor = 1.0 + bulge_noise * 0.4
			
			rough_y *= bulge_factor
			rough_z *= bulge_factor
			
			rock_vertices.append(Vector3(rough_x, rough_y, rough_z))

func generate_indices():
	# Generate triangular faces for the mesh
	for i in range(segments_length):
		for j in range(segments_circumference):
			var current = i * segments_circumference + j
			var next_u = (i + 1) * segments_circumference + j
			var next_v = i * segments_circumference + ((j + 1) % segments_circumference)
			var next_both = (i + 1) * segments_circumference + ((j + 1) % segments_circumference)
			
			# Create two triangles per quad (counter-clockwise winding for outward normals)
			# Triangle 1
			rock_indices.append(current)
			rock_indices.append(next_u)
			rock_indices.append(next_v)
			
			# Triangle 2
			rock_indices.append(next_v)
			rock_indices.append(next_u)
			rock_indices.append(next_both)

func create_convex_shape() -> ConvexPolygonShape3D:
	var shape = ConvexPolygonShape3D.new()
	shape.points = rock_vertices
	return shape

func create_array_mesh() -> ArrayMesh:
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	
	# Calculate normals
	var normals = calculate_normals()
	
	# Calculate UVs (simple cylindrical mapping)
	var uvs = calculate_uvs()
	
	arrays[Mesh.ARRAY_VERTEX] = rock_vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = rock_indices
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return array_mesh

func calculate_normals() -> PackedVector3Array:
	var normals = PackedVector3Array()
	normals.resize(rock_vertices.size())
	
	# Initialize all normals to zero
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO
	
	# Calculate face normals and accumulate to vertices
	for i in range(0, rock_indices.size(), 3):
		var i0 = rock_indices[i]
		var i1 = rock_indices[i + 1]
		var i2 = rock_indices[i + 2]
		
		var v0 = rock_vertices[i0]
		var v1 = rock_vertices[i1]
		var v2 = rock_vertices[i2]
		
		var face_normal = (v1 - v0).cross(v2 - v0).normalized()
		
		normals[i0] += face_normal
		normals[i1] += face_normal
		normals[i2] += face_normal
	
	# Normalize all vertex normals
	for i in range(normals.size()):
		normals[i] = normals[i].normalized()
	
	return normals

func calculate_uvs() -> PackedVector2Array:
	var uvs = PackedVector2Array()
	uvs.resize(rock_vertices.size())
	
	for i in range(rock_vertices.size()):
		var vertex = rock_vertices[i]
		
		# Simple cylindrical UV mapping
		var u = (vertex.x + rock_length * 0.5) / rock_length
		var v = atan2(vertex.z, vertex.y) / TAU + 0.5
		
		uvs[i] = Vector2(u, v)
	
	return uvs

# Convenience function to create a complete rock rigidbody
func create_rock_staticbody(position: Vector3 = Vector3.ZERO) -> StaticBody3D:
	generate_rock()
	
	var rigidbody = StaticBody3D.new()
	rigidbody.position = position
	
	# Create mesh instance
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = create_array_mesh()
	rigidbody.add_child(mesh_instance)
	
	# Create collision shape
	var collision_shape = CollisionShape3D.new()
	collision_shape.shape = create_convex_shape()
	rigidbody.add_child(collision_shape)
	
	return rigidbody#StaticBody3D

# Generate multiple rock variations
func generate_rock_variations(count: int) -> Array[Dictionary]:
	var variations = []
	
	for i in range(count):
		# Randomize parameters for variation
		var old_noise_strength = noise_strength
		var old_roughness = roughness
		var old_randomness = randomness
		var old_taper = taper_strength
		
		noise_strength = randf_range(0.2, 0.5)
		roughness = randf_range(0.3, 0.7)
		randomness = randf_range(0.1, 0.3)
		taper_strength = randf_range(0.2, 0.5)
		
		var rock_data = generate_rock()
		variations.append(rock_data)
		
		# Restore original parameters
		noise_strength = old_noise_strength
		roughness = old_roughness
		randomness = old_randomness
		taper_strength = old_taper
	
	return variations

func addStick(stick:RigidBody3D, container:GridContainer, backGround:Node3D) -> void:
	#camera = Camera3D.new()
	stickBody = stick
	#self.get_parent().add_child(camera)
	#camera.position = Vector3(0,2,-5)
	stick.freeze = false
	container.visible = false
	print(backGround)
	backGround.queue_free()
	backGround.visible = false
	backGround.hide()
	print(backGround)
