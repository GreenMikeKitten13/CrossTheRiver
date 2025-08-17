extends RigidBody3D

# Water simulation parameters
@export var water_level: float = -1.0
@export var water_density: float = 1000.0
@export var buoyancy_strength: float = 0.08#1.0
#var river_strength:float = 1000000000000000000
@export var linear_drag: float = 2.0
@export var angular_drag: float = 1.0
@export var river_velocity: Vector3 = Vector3(0.1, 0.0, 0.0)
@export var sample_points_per_cylinder: int = 10
@export var surface_sample_points_per_cylinder: int = 5
var total_drag_force:Vector3 =Vector3.ZERO
@onready var control = self.get_meta("control")

# Internal variables
var submerged_volume: float = 0.0
var total_volume: float = 0.0
var buoyancy_center: Vector3 = Vector3.ZERO
var cylinder_data: Array[Dictionary] = []

func _ready():
	calculate_cylinder_data()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Left"):
		river_velocity = Vector3(0.1,0,-control)
	if event.is_action_pressed("Right"):
		river_velocity = Vector3(0.1,0,control)
	if !event.is_action_pressed("Left") and !event.is_action_pressed("Right"):
		river_velocity = Vector3(0.1,0,0)
	#if !(river_velocity == Vector3(0.1,0,control) or river_velocity == Vector3(0.1,0, -control)):
	#	river_velocity = Vector3(0.1,0,0)
	print(river_velocity)

func calculate_cylinder_data():
	cylinder_data.clear()
	total_volume = 0.0
	
	# Find all MeshInstance3D children that represent cylinders
	for child in get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			var mesh = child.mesh as CylinderMesh
			var cylinder_info = {
				"mesh_instance": child,
				"top_radius": mesh.top_radius,
				"bottom_radius": mesh.bottom_radius,
				"height": mesh.height,
				"position": child.position,
				"rotation": child.rotation,
				"volume": 0.0
			}
			
			# Calculate volume for this cylinder
			cylinder_info["volume"] = PI * mesh.height * (mesh.top_radius * mesh.top_radius + 
				mesh.top_radius * mesh.bottom_radius + 
				mesh.bottom_radius * mesh.bottom_radius) / 3.0
			
			total_volume += cylinder_info["volume"]
			cylinder_data.append(cylinder_info)
	
	if cylinder_data.is_empty():
		push_warning("No cylinder meshes found in rigidbody children!")

func _integrate_forces(state):
	apply_water_forces(state)

func apply_water_forces(state):
	# Reset values
	submerged_volume = 0.0
	buoyancy_center = Vector3.ZERO
	var total_submerged_points = 0
	#var total_sample_points = 0
	
	# Get world transform
	var world_transform = state.transform
	
	# Process each cylinder
	for cylinder_info in cylinder_data:
		#var mesh_instance = cylinder_info["mesh_instance"] as MeshInstance3D
		var top_radius = cylinder_info["top_radius"]
		var bottom_radius = cylinder_info["bottom_radius"]
		var height = cylinder_info["height"]
		# Safely create the local transform with rotation validation
		var sotation = cylinder_info["rotation"] as Vector3
		var local_transform = Transform3D()
		
		# Validate rotation vector and create basis safely
		if sotation.length_squared() > 0.0001:  # Only apply rotation if significant
			var validated_rotation = validate_vector(sotation)
			if validated_rotation != Vector3.ZERO:
				local_transform.basis = Basis.from_euler(validated_rotation)
		
		local_transform.origin = cylinder_info["position"]
		
		var cylinder_submerged_points = 0
		@warning_ignore("unused_variable")
		var cylinder_buoyancy_center = Vector3.ZERO
		
		# Sample points inside this cylinder
		for i in range(sample_points_per_cylinder):
			var cylinder_local_point = get_random_point_in_cylinder(top_radius, bottom_radius, height)
			var rigidbody_local_point = local_transform * cylinder_local_point
			var world_point = world_transform * rigidbody_local_point
			
			#total_sample_points += 1
			if world_point.y < water_level:
				cylinder_submerged_points += 1
				total_submerged_points += 1
				cylinder_buoyancy_center += rigidbody_local_point
				buoyancy_center += rigidbody_local_point
		
		# Calculate this cylinder's contribution to submerged volume
		if cylinder_submerged_points > 0:
			var cylinder_submersion_ratio = float(cylinder_submerged_points) / float(sample_points_per_cylinder)
			submerged_volume += cylinder_submersion_ratio * cylinder_info["volume"]
	
	# Finalize buoyancy center
	if total_submerged_points > 0:
		buoyancy_center /= total_submerged_points
	
	# Apply forces if partially or fully submerged
	if submerged_volume > 0.0:
		apply_buoyancy_force(state)
		apply_water_drag(state)
		apply_river_force(state)

func apply_buoyancy_force(state):
	# Calculate buoyancy force (Archimedes' principle)
	var buoyancy_force = Vector3.UP * water_density * submerged_volume * 9.81 * buoyancy_strength
	
	# Validate and clamp the force
	buoyancy_force = validate_vector(buoyancy_force)
	buoyancy_force = buoyancy_force.limit_length(mass * 50.0)  # Prevent excessive forces
	
	# Apply force at the center of buoyancy
	if buoyancy_center.length() > 0.001:  # Avoid applying force at exactly zero
		state.apply_force(buoyancy_force, buoyancy_center)
	else:
		state.apply_central_force(buoyancy_force)

func apply_water_drag(state):
	total_drag_force = Vector3.ZERO
	var total_drag_torque = Vector3.ZERO
	var total_surface_points_in_water = 0
	#var total_surface_points = 0
	
	# Process drag for each cylinder
	for cylinder_info in cylinder_data:
		var top_radius = cylinder_info["top_radius"]
		var bottom_radius = cylinder_info["bottom_radius"]
		var height = cylinder_info["height"]
		# Safely create the local transform with rotation validation
		var sotation = cylinder_info["rotation"] as Vector3
		var local_transform = Transform3D()
		
		# Validate rotation vector and create basis safely
		if sotation.length_squared() > 0.0001:  # Only apply rotation if significant
			var validated_rotation = validate_vector(sotation)
			if validated_rotation != Vector3.ZERO:
				local_transform.basis = Basis.from_euler(validated_rotation)
		
		local_transform.origin = cylinder_info["position"]
		
		# Sample surface points on this cylinder
		for i in range(surface_sample_points_per_cylinder):
			var cylinder_local_point = get_random_point_on_cylinder_surface(top_radius, bottom_radius, height)
			var rigidbody_local_point = local_transform * cylinder_local_point
			var world_point = state.transform * rigidbody_local_point
			
			#total_surface_points += 1
			
			if world_point.y < water_level:
				total_surface_points_in_water += 1
				
				# Calculate relative velocity at this point
				var point_velocity = state.linear_velocity + state.angular_velocity.cross(rigidbody_local_point)
				var relative_velocity = point_velocity - river_velocity
				
				# Calculate drag force
				if relative_velocity.length_squared() > 0.001:
					var drag_direction = -relative_velocity.normalized()
					var drag_magnitude = linear_drag * relative_velocity.length_squared()
					var drag_force = drag_direction * drag_magnitude
					
					# Scale drag by cylinder volume contribution
					var volume_ratio = cylinder_info["volume"] / total_volume
					drag_force *= volume_ratio
					
					# Validate and accumulate drag force
					drag_force = validate_vector(drag_force)
					drag_force = drag_force.limit_length(mass * 10.0)  # Prevent excessive drag per point
					
					total_drag_force += drag_force
					total_drag_torque += rigidbody_local_point.cross(drag_force)
	
	# Apply averaged drag forces
	if total_surface_points_in_water > 0:
		total_drag_force /= total_surface_points_in_water
		total_drag_torque /= total_surface_points_in_water
		
		# Scale by submersion ratio
		var submersion_ratio = submerged_volume / total_volume if total_volume > 0 else 0.0
		total_drag_force *= submersion_ratio
		total_drag_torque *= submersion_ratio
		
		state.apply_central_force(total_drag_force)
		
		# Apply angular drag
		var angular_drag_torque = -state.angular_velocity * angular_drag * submersion_ratio
		angular_drag_torque = validate_vector(angular_drag_torque)
		total_drag_torque += angular_drag_torque
		
		state.apply_torque(total_drag_torque)

func apply_river_force(state):
	# Apply river current force proportional to submerged volume
	var submersion_ratio = submerged_volume / total_volume if total_volume > 0 else 0.0
	var river_force = river_velocity * submersion_ratio #/ river_strength #0.5 instead of river_streng* water_density *th
	river_force = validate_vector(river_force)
	river_force = river_force.limit_length(mass * 10.0)  # Prevent excessive river forces
	
	state.apply_central_force(river_force)

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

func validate_vector(vec: Vector3) -> Vector3:
	# Check for NaN or infinite values
	if is_nan(vec.x) or is_nan(vec.y) or is_nan(vec.z) or is_inf(vec.x) or is_inf(vec.y) or is_inf(vec.z):
		return Vector3.ZERO
	
	# Check for extremely small values that might cause numerical issues
	var cleaned_vec = Vector3(
		0.0 if abs(vec.x) < 1e-6 else vec.x,
		0.0 if abs(vec.y) < 1e-6 else vec.y,
		0.0 if abs(vec.z) < 1e-6 else vec.z
	)
	
	# Return the validated vector
	return cleaned_vec

# Call this if cylinders are added/removed dynamically
func refresh_cylinder_data():
	calculate_cylinder_data()

# Optional: Get current water interaction info
func get_water_info() -> Dictionary:
	return {
		"submerged_volume": submerged_volume,
		"total_volume": total_volume,
		"submersion_ratio": submerged_volume / total_volume if total_volume > 0 else 0.0,
		"buoyancy_center": buoyancy_center,
		"is_floating": submerged_volume > 0.0,
		"cylinder_count": cylinder_data.size()
	}
