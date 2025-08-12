extends RigidBody3D

# Physics constants
const WATER_DENSITY: float = 1000.0  # kg/m³
const AIR_DENSITY: float = 1.2       # kg/m³
const DRAG_COEFFICIENT: float = 0.8  # More realistic for irregular shapes
const ANGULAR_DRAG_COEFFICIENT: float = 0.1
const WATER_LEVEL: float = 2.0
const HOLLOWNESS_RATIO: float = 0.99  # 0=solid, 1=completely hollow

# Sampling parameters
const SAMPLES_PER_CYLINDER: int = 40
const UPDATE_INTERVAL: float = 0.05

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var timer: float = 0.0
var cylinder_data: Array = []
var stick_density: float = 500.0  # Initial density (will be calculated)

class CylinderData:
	var node: Node3D
	var volume_points: Array[Vector3] = []
	var area_points: Array[Vector3] = []
	var volume: float = 0.0
	var surface_area: float = 0.0
	
	func _init(_node: Node3D):
		node = _node
		generate_points()
		calculate_volume_and_area()

	# Helper functions
	func get_random_point_in_cylinder(top_r: float, bottom_r: float, height: float) -> Vector3:
		var y = randf_range(-height/2, height/2)
		var t = (y + height/2) / height
		var radius = lerp(bottom_r, top_r, t)
		var angle = randf_range(0, TAU)
		var r = sqrt(randf()) * radius
		return Vector3(r * cos(angle), y, r * sin(angle))

	func get_random_point_on_cylinder_surface(top_r: float, bottom_r: float, height: float) -> Vector3:
		var y = randf_range(-height/2, height/2)
		var t = (y + height/2) / height
		var radius = lerp(bottom_r, top_r, t)
		var angle = randf_range(0, TAU)
		return Vector3(radius * cos(angle), y, radius * sin(angle))
		
	func frustum_volume(top_r: float, bottom_r: float, height: float) -> float:
		return (PI * height / 3.0) * (top_r*top_r + top_r*bottom_r + bottom_r*bottom_r)
	
	func frustum_surface_area(top_r: float, bottom_r: float, height: float) -> float:
		var slant = sqrt(height*height + pow(top_r - bottom_r, 2))
		return PI * (top_r + bottom_r) * slant + PI * (top_r*top_r + bottom_r*bottom_r)
	
	func generate_points():
		if node.mesh is CylinderMesh:
			var mesh: CylinderMesh = node.mesh
			for i in SAMPLES_PER_CYLINDER:
				volume_points.append(get_random_point_in_cylinder(mesh.top_radius, mesh.bottom_radius, mesh.height))
				area_points.append(get_random_point_on_cylinder_surface(mesh.top_radius, mesh.bottom_radius, mesh.height))
	
	func calculate_volume_and_area():
		if node.mesh is CylinderMesh:
			var mesh: CylinderMesh = node.mesh
			volume = frustum_volume(mesh.top_radius, mesh.bottom_radius, mesh.height)
			surface_area = frustum_surface_area(mesh.top_radius, mesh.bottom_radius, mesh.height)

# Helper functions


#func frustum_surface_area(top_r: float, bottom_r: float, height: float) -> float:
#	var slant = sqrt(height*height + pow(top_r - bottom_r, 2))
#	return PI * (top_r + bottom_r) * slant + PI * (top_r*top_r + bottom_r*bottom_r)

func get_velocity_at_position(global_point: Vector3) -> Vector3:
	var com = global_transform * center_of_mass
	return linear_velocity + (angular_velocity).cross(global_point - com)

func _ready():
	var total_volume: float = 0.0
	for child in get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			var data = CylinderData.new(child)
			cylinder_data.append(data)
			total_volume += data.volume

	var solid_density = 300.0 # or random if you want variation
	var hollowness = 0.7       # 0 = solid, 0.7 = mostly hollow
	stick_density = lerp(solid_density, solid_density * 0.1, hollowness)

	# ✅ Mass reflects hollowness
	self.mass = total_volume * stick_density

	print("Stick Volume:", total_volume, " Density:", stick_density, " Mass:", mass)
	inertia = Vector3.ONE * mass * 0.5

#var river_velocity:Vector3 = Vector3(1,0,0)
#var river_strength:float = 0.5


func _physics_process(delta: float) -> void:
	timer += delta
	if timer < UPDATE_INTERVAL:
		return
	timer = 0
	
	apply_central_force(Vector3(1,0,0) * mass)
	#linear_velocity = linear_velocity.lerp(river_velocity, river_strength)
	
	for child in self.get_children():
		if child.name.begins_with("bup"):
			child.queue_free()
	
	
	# Reset forces
	#var total_buoyancy = Vector3.ZERO
	#var _total_drag = Vector3.ZERO
	
	for data in cylinder_data:
		if not is_instance_valid(data.node):
			continue
			
		#var mesh: CylinderMesh = data.node.mesh
		var sransform: Transform3D = data.node.global_transform
		
		# Calculate submerged volume and buoyancy
		var submerged_points: int = 0
		var buoyancy_center = Vector3.ZERO
		
		for point in data.volume_points:
			var global_point = sransform * point
			if global_point.y <= WATER_LEVEL:
				submerged_points += 1
				buoyancy_center += global_point
				#var test:MeshInstance3D = MeshInstance3D.new()
				#var testMesh:BoxMesh = BoxMesh.new()
				#testMesh.size = Vector3.ONE/5
				#test.name = "bup"
				#test.mesh = testMesh
				#self.add_child(test)
		
		# Apply buoyancy if any part is submerged
		if submerged_points > 0:
			buoyancy_center /= submerged_points
			var submerged_ratio = float(submerged_points) / SAMPLES_PER_CYLINDER
			
			# Archimedes' principle: F_b = ρ_fluid * g * V_submerged
			var submerged_volume = data.volume * submerged_ratio
			var buoyancy_force =( WATER_DENSITY * gravity * submerged_volume)
			
			# Apply buoyancy force
			#total_buoyancy += Vector3(0, buoyancy_force, 0)
			apply_force(Vector3(0, buoyancy_force, 0), buoyancy_center)
		
		# Calculate drag forces
		for area_point in data.area_points:#transform
			var global_point = sransform * area_point
			var is_underwater = global_point.y <= WATER_LEVEL
			var density = WATER_DENSITY if is_underwater else AIR_DENSITY
			
			if not is_underwater:
				# Only apply significant drag underwater
				continue
				
			var velocity = get_velocity_at_position(global_point)
			var speed = velocity.length()
			if speed < 0.01:
				continue
				
			# Drag force: F_d = 0.5 * ρ * v² * C_d * A
			var surface_area = data.surface_area / SAMPLES_PER_CYLINDER
			var drag_magnitude = 0.5 * density * speed * speed * DRAG_COEFFICIENT * surface_area
			var drag_force = -velocity.normalized() * drag_magnitude
			
			#_total_drag += drag_force
			apply_force(drag_force, global_point)
	
	# Apply downward gravity force (adjusted for buoyancy)
	#var net_gravity_force = Vector3(0, gravity * mass, 0) - total_buoyancy
	#apply_force(net_gravity_force, global_transform.origin)
	
	# Apply angular damping (water resistance to rotation)
	if angular_velocity.length() > 0.1:
		var angular_drag = -angular_velocity.normalized() * angular_velocity.length_squared() * ANGULAR_DRAG_COEFFICIENT * WATER_DENSITY
		apply_torque(angular_drag)
