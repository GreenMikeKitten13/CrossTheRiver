extends CharacterBody3D

var savePath = "user://inventory.tres"
const placeHolderMaterial = preload("res://materials/placeHoldMaterial.tres")

@export_group("Cammera")
@export_range(0.1, 1) var mouseSensetivity:float = 0.25

@export_group("Movement")
@export var speed :float= 8.8
@export var acceleration :float= 22.0
@export var rotationSpeed :float=12.0
@export var jumpImpulse :float=12.0

@export var renderDistance:int = 40

@onready var cameraPivot: Node3D = %CameraPivot
@onready var camera: Camera3D = %Camera3D
@onready var playerMesh: MeshInstance3D = %playerMesh
@onready var rayCast: RayCast3D = %RayCast3D

var pickUp:bool = true
var lastMovementDirection:Vector3 = Vector3.BACK
var cameraInputDirection :Vector2= Vector2.ZERO
var Gravity :int= -30
var inventory:Dictionary = {}

@onready var saveEverything = saveData.new()

const stickPicture = preload("res://scenes/StickPicture.tscn")
const StickScript = preload("res://scripts/stickScript.gd")
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	var inventoryData := ResourceLoader.load(savePath) as saveData
	if inventoryData:
		inventory.assign(inventoryData.inventory)

		for stickName in inventory.keys():
			var stickData:Dictionary = inventory[stickName]
			#var points:Array[Vector3] = []
			
			var stickBody:RigidBody3D = RigidBody3D.new()
			stickBody.set_script(StickScript)
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
				# Create child transform from rotation (Euler angles) and position
				#var rotation_euler: Vector3 = childData[1]  # ensure radians
				#rotation_euler = Vector3(deg_to_rad(rotation_euler.x), deg_to_rad(rotation_euler.y), deg_to_rad(rotation_euler.z))
				#var quat = Quaternion()
				#quat = Quaternion.from_euler(rotation_euler)
				#Quaternion.from_euler(rotation_euler)
				#var sasis = Basis(quat)
				#var child_transform = Transform3D(sasis, childData[0])

				#for i in range(1000):
				#	var local_point = get_random_point_in_cylinder(childData[2], childData[3])
				#	var global_point = child_transform * local_point  # use * instead of xform
				#	points.append(global_point)


			#var container:GridContainer = %inventory.get_child(0)
		#	var newStickPicture:SubViewportContainer = stickPicture.instantiate()
			#var subViewPort:SubViewport = newStickPicture.get_child(0)
			

		#	subViewPort.add_child(stickBody)
		#	stickBody.position = Vector3.UP
			#for point:Vector3 in points:
			#	var test:MeshInstance3D = MeshInstance3D.new()
			#	var testMesh:BoxMesh =  BoxMesh.new()
			#	testMesh.size = Vector3(0.01, 0.01, 0.01 )
			#	test.mesh =testMesh
			#	test.position = point
			#	stickBody.add_child(test)
		#	stickBody.set_meta("points", points)

		#	container.add_child(newStickPicture)


			# You can also reapply stats if needed:
			#var stickSpeed = stickData["speed"]
			#var stickControl = stickData["control"]
			#var stickHollow = stickData["hollow"]




func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("interact") and pickUp:
		addToInventory(rayCast.get_collider())
		#print("picked up : " + rayCast.get_collider().name)

func _unhandled_input(event: InputEvent) -> void:
	var isCameraMotion :bool = event is InputEventMouseMotion
	if event is InputEventMouseButton:
		if event.is_pressed():
			var SpringArm = %SpringArm3D
			if event.button_index == MOUSE_BUTTON_WHEEL_UP && SpringArm.spring_length > 0:
				SpringArm.spring_length -= 0.1
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN && SpringArm.spring_length < 20:
				SpringArm.spring_length += 0.1
	
	if isCameraMotion:
		cameraInputDirection = event.screen_relative * mouseSensetivity


func _physics_process(delta: float) -> void:
	cameraPivot.rotation.x += -cameraInputDirection.y * delta
	cameraPivot.rotation.x = clamp(cameraPivot.rotation.x, -PI/2.2, PI/2.2)
	cameraPivot.rotation.y -= cameraInputDirection.x * delta
	
	cameraInputDirection = Vector2.ZERO
	var rawInput :Vector2= Input.get_vector("Left","Right","Forward","Backward")
	var forward :Vector3= camera.global_basis.z
	var right :Vector3= camera.global_basis.x
	
	var moveDirection :Vector3= forward * rawInput.y + right * rawInput.x
	moveDirection.y = 0.0
	moveDirection = moveDirection.normalized()
	
	var yVelocity : float= velocity.y
	velocity.y = 0.0
	velocity = velocity.move_toward(moveDirection * speed, acceleration * delta)
	velocity.y = yVelocity + Gravity * delta
	
	#var isStartingJump :bool = Input.is_action_just_pressed("Jump") and is_on_floor()
	#if isStartingJump:
	#	velocity.y += jumpImpulse
	
	
	move_and_slide()

	if moveDirection.length() > 0.2:
		lastMovementDirection = moveDirection

	var targetAngle :float= Vector3.BACK.signed_angle_to(lastMovementDirection, Vector3.UP)
	playerMesh.global_rotation.y = lerp_angle(playerMesh.rotation.y, targetAngle, rotationSpeed * delta)
	
	if rayCast.get_collider() and rayCast.get_collider().has_meta("stick"):
		%EToPickUp.visible = true
		pickUp = true
	else:
		%EToPickUp.visible = false
		pickUp = false

func addToInventory(stickBody: RigidBody3D):
	var stickSpeed: float = randf_range(0.5, 3)
	var stickControl: float = randf_range(0.15, 2)
	var stickHollow: float = randf_range(300, 900)
	var stickColor:Color = Color(0,0,0)
	
	inventory[stickBody.name] = {#.assign({stickBody.name : {
		"speed": stickSpeed,
		"control": stickControl,
		"hollow": stickHollow,
		"position": stickBody.position}
		
	inventory[stickBody.name]["children"] = {}
	
	for child:Node3D in stickBody.get_children():
		if child is  MeshInstance3D:
			var childMesh = child.mesh
			if stickColor == Color(0,0,0):
				stickColor = childMesh.material.albedo_color
				inventory[stickBody.name]["color"] = stickColor#.assign({"color" : stickColor})
				
			inventory[stickBody.name]["children"][child.name] = [ stickBody.to_local(child.global_transform.origin), child.rotation, childMesh.top_radius, childMesh.height]#.assign({child.name : })
			child.mesh.material = placeHolderMaterial 

	saveEverything.inventory = inventory
	print(inventory)
	ResourceSaver.save(saveEverything, savePath)

func get_random_point_in_cylinder(radius: float, height: float) -> Vector3:
	var angle = randf() * TAU
	var r = sqrt(randf()) * radius
	var x = r * cos(angle)
	var z = r * sin(angle)
	var y = randf() * height - height * 0.5
	return Vector3(x, y, z)
