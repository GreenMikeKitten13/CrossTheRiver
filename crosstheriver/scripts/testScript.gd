extends MeshInstance3D

@export var segments := 16
@export var radius := 0.2
@export var height := 2.0

@onready var array_mesh := ArrayMesh.new()
var branches:Array = []

func _ready():
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()

	var top_center = Vector3(0 +randf_range(0,0.05), height / 2, 0 +randf_range(0,0.05))
	var bottom_center = Vector3(0 +randf_range(0,0.05), -height / 2, 0 +randf_range(0,0.05))

	# Add top and bottom center
	positions.append(top_center)
	normals.append(Vector3.UP)

	positions.append(bottom_center)
	normals.append(Vector3.DOWN)

	# Add top and bottom ring points
	for i in range(segments):
		var angle = TAU * i / segments
		var x = cos(angle) * radius
		var z = sin(angle) * radius

		# Top ring
		positions.append(Vector3(x + randf_range(0,0.05), height / 2, z + randf_range(0,0.05)))
		normals.append(Vector3.UP)

		# Bottom ring
		positions.append(Vector3(x+randf_range(0,0.05), -height / 2, z+randf_range(0,0.05)))
		normals.append(Vector3.DOWN)

	# Top cap
	for i in range(segments):
		var next = (i + 1) % segments
		indices.append_array([
			0, 2 + i * 2, 2 + next * 2
		])

	# Bottom cap (flip order)
	for i in range(segments):
		var next = (i + 1) % segments
		indices.append_array([
			1, 3 + next * 2, 3 + i * 2
		])

	# Side faces
	for i in range(segments):
		var next = (i + 1) % segments
		var top1 = 2 + i * 2
		var bottom1 = 3 + i * 2
		var top2 = 2 + next * 2
		var bottom2 = 3 + next * 2

		indices.append_array([top1, bottom1, bottom2])
		indices.append_array([top1, bottom2, top2])

		# Normals for the sides (average of ring direction)
		var normal = Vector3(cos(TAU * i / segments), 0, sin(TAU * i / segments))
		normals[top1] = normal
		normals[bottom1] = normal

		normal = Vector3(cos(TAU * next / segments), 0, sin(TAU * next / segments))
		normals[top2] = normal
		normals[bottom2] = normal

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.3, 0.1)
	array_mesh.surface_set_material(0, mat)
	
	#for branch in randi_range(1, 7):
	#	var pos = Vector3(randf_range(0.25, 0.5), randf_range(0.25, 0.5), randf_range(0.25, 0.5))
	#	var dir =  Vector3(randf_range(1, 5), randf_range(1, 5), randf_range(1, 5))
	#	add_branch(pos, dir,randf_range(1, 5))
		
	mesh = array_mesh


#func add_branch(branchPosition: Vector3, direction: Vector3, length: float):
#	var branch = MeshInstance3D.new()
#	branch.mesh = array_mesh
#	var randLength = randf_range(0.25, 0.5)
#	branch.scale = Vector3(randLength, randLength,randLength)  # height goes in Y 1, length / 2.0, 1
#	branch.transform = Transform3D(Basis().looking_at(direction, Vector3.UP), branchPosition)
#	add_child(branch)
	
#	var tip = branchPosition + direction.normalized() * randLength
##	branch.set_meta("tip_position", tip)
#	branches.append(branch)
