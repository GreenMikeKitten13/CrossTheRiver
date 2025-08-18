# LobbyManager.gd
extends Node

signal lobby_created(lobby_id)
signal lobby_joined(lobby_id)
signal lobby_error(message)
signal player_joined_lobby(player_name)
signal player_left_lobby(player_name)

var nakama_client: NakamaClient
var nakama_session: NakamaSession
var nakama_socket: NakamaSocket
var current_lobby_id: String = ""
var is_lobby_host: bool = false

func _ready():
	# Connect to Nakama
	nakama_client = Nakama.create_client("defaultkey", "127.0.0.1", 7350, "http")
	connect_to_server()

func connect_to_server():
	print("Connecting to Nakama...")
	var session_result = await nakama_client.authenticate_device_async(OS.get_unique_id())
	
	if session_result.is_exception():
		lobby_error.emit("Failed to connect: " + str(session_result.get_exception()))
		return
	
	nakama_session = session_result
	print("Session created for user: ", nakama_session.user_id)
	
	# Create socket connection for real-time features
	nakama_socket = Nakama.create_socket_from(nakama_client)
	
	# Connect socket event handlers
	nakama_socket.connected.connect(_on_socket_connected)
	nakama_socket.closed.connect(_on_socket_closed)
	nakama_socket.received_error.connect(_on_socket_error)
	nakama_socket.received_match_state.connect(_on_match_state_received)
	nakama_socket.received_match_presence.connect(_on_match_presence_received)
	
	var socket_result = await nakama_socket.connect_async(nakama_session)
	
	if socket_result.is_exception():
		lobby_error.emit("Failed to connect socket: " + str(socket_result.get_exception()))
		return
	
	print("Connected! User ID: ", nakama_session.user_id)

func _on_socket_connected():
	print("Socket connected successfully")

func _on_socket_closed():
	print("Socket connection closed")

func _on_socket_error(error):
	print("Socket error: ", error)
	lobby_error.emit("Socket error: " + str(error))

func _on_match_state_received(match_state):
	# Handle incoming match data
	var data = match_state.data.get_string_from_utf8()
	print("Received match data: ", data)

func _on_match_presence_received(match_presence_event):
	# Handle players joining/leaving
	for presence in match_presence_event.joins:
		print("Player joined: ", presence.username)
		player_joined_lobby.emit(presence.username)
	
	for presence in match_presence_event.leaves:
		print("Player left: ", presence.username)  
		player_left_lobby.emit(presence.username)

## PUBLIC LOBBY FUNCTIONS

func create_public_lobby(lobby_name: String, max_players: int = 10):
	"""Create a public lobby that anyone can join"""
	if not nakama_session or not nakama_socket:
		lobby_error.emit("Not connected to server")
		return
	
	print("Creating public lobby: ", lobby_name)
	
	# Create match using socket
	var result = await nakama_socket.create_match_async()
	
	if result.is_exception():
		lobby_error.emit("Failed to create lobby: " + str(result.get_exception()))
		return
	
	current_lobby_id = result.match_id
	is_lobby_host = true
	
	# Store lobby metadata using storage
	var lobby_data = {
		"lobby_name": lobby_name,
		"lobby_type": "public",
		"max_players": max_players,
		"current_players": 1,
		"host_name": nakama_session.username if nakama_session.username else nakama_session.user_id,
		"match_id": current_lobby_id,
		"created_at": Time.get_unix_time_from_system()
	}
	
	# Store in user storage for easy retrieval
	var storage_objects = []
	var storage_write = NakamaWriteStorageObject.new("public_lobbies", current_lobby_id, 1, 2, JSON.stringify(lobby_data), "")
	storage_objects.append(storage_write)
	
	var storage_result = await nakama_client.write_storage_objects_async(nakama_session, storage_objects)
	if storage_result.is_exception():
		print("Warning: Failed to store lobby metadata: ", storage_result.get_exception())
	
	lobby_created.emit(current_lobby_id)
	print("Public lobby created with ID: ", current_lobby_id)

func join_public_lobby(lobby_id: String):
	"""Join a public lobby by ID"""
	if not nakama_session or not nakama_socket:
		lobby_error.emit("Not connected to server")
		return
	
	print("Joining public lobby: ", lobby_id)
	
	var result = await nakama_socket.join_match_async(lobby_id)
	
	if result.is_exception():
		lobby_error.emit("Failed to join lobby: " + str(result.get_exception()))
		return
	
	current_lobby_id = lobby_id
	is_lobby_host = false
	
	lobby_joined.emit(lobby_id)
	print("Joined public lobby: ", lobby_id)

func list_public_lobbies():
	"""Get list of all public lobbies"""
	if not nakama_session:
		lobby_error.emit("Not connected to server")
		return []
	
	print("Fetching public lobbies...")
	
	# Read from storage to get lobby list
	var result = await nakama_client.list_storage_objects_async(nakama_session, "public_lobbies", "", 100)
	
	if result.is_exception():
		lobby_error.emit("Failed to get lobby list: " + str(result.get_exception()))
		return []
	
	var public_lobbies = []
	for storage_object in result.objects:
		var lobby_data_result = JSON.parse_string(storage_object.value)
		if lobby_data_result != null:
			var lobby_data = lobby_data_result
			# Check if lobby is still valid (not too old)
			var created_at = lobby_data.get("created_at", 0)
			var current_time = Time.get_unix_time_from_system()
			
			# Skip lobbies older than 1 hour
			if current_time - created_at > 3600:
				continue
				
			public_lobbies.append({
				"id": lobby_data.get("match_id", ""),
				"name": lobby_data.get("lobby_name", "Unknown"),
				"players": lobby_data.get("current_players", 0),
				"max_players": lobby_data.get("max_players", 10),
				"host": lobby_data.get("host_name", "Unknown")
			})
	
	print("Found ", public_lobbies.size(), " public lobbies")
	return public_lobbies

## PRIVATE LOBBY FUNCTIONS

func create_private_lobby(lobby_name: String, password: String, max_players: int = 10):
	"""Create a private lobby with password protection"""
	if not nakama_session or not nakama_socket:
		lobby_error.emit("Not connected to server")
		return
	
	print("Creating private lobby: ", lobby_name)
	
	var result = await nakama_socket.create_match_async()
	
	if result.is_exception():
		lobby_error.emit("Failed to create private lobby: " + str(result.get_exception()))
		return
	
	current_lobby_id = result.match_id
	is_lobby_host = true
	
	# Hash the password for basic security
	var password_hash = password.sha256_text()
	
	# Store lobby metadata with password
	var lobby_data = {
		"lobby_name": lobby_name,
		"lobby_type": "private",
		"password_hash": password_hash,
		"max_players": max_players,
		"current_players": 1,
		"host_name": nakama_session.username if nakama_session.username else nakama_session.user_id,
		"match_id": current_lobby_id,
		"created_at": Time.get_unix_time_from_system()
	}
	
	# Store in private collection
	var storage_objects = []
	var storage_write = NakamaWriteStorageObject.new("private_lobbies", current_lobby_id, 1, 1, JSON.stringify(lobby_data), "")
	storage_objects.append(storage_write)
	
	var storage_result = await nakama_client.write_storage_objects_async(nakama_session, storage_objects)
	if storage_result.is_exception():
		print("Warning: Failed to store private lobby metadata: ", storage_result.get_exception())
	
	lobby_created.emit(current_lobby_id)
	print("Private lobby created with ID: ", current_lobby_id)

func join_private_lobby(lobby_id: String, password: String):
	"""Join a private lobby with password"""
	if not nakama_session or not nakama_socket:
		lobby_error.emit("Not connected to server")
		return
	
	print("Attempting to join private lobby: ", lobby_id)
	
	# Get lobby info from storage
	var storage_ids = []
	var storage_id = NakamaStorageObjectId.new("private_lobbies", lobby_id)
	storage_ids.append(storage_id)
	
	var storage_result = await nakama_client.read_storage_objects_async(nakama_session, storage_ids)
	
	if storage_result.is_exception() or storage_result.objects.size() == 0:
		lobby_error.emit("Private lobby not found")
		return
	
	var lobby_data_result = JSON.parse_string(storage_result.objects[0].value)
	if lobby_data_result == null:
		lobby_error.emit("Invalid lobby data")
		return
	
	var lobby_data = lobby_data_result
	
	# Check password
	var stored_hash = lobby_data.get("password_hash", "")
	var provided_hash = password.sha256_text()
	
	if stored_hash != provided_hash:
		lobby_error.emit("Incorrect password")
		return
	
	# Password correct, join the match
	var join_result = await nakama_socket.join_match_async(lobby_id)
	
	if join_result.is_exception():
		lobby_error.emit("Failed to join lobby: " + str(join_result.get_exception()))
		return
	
	current_lobby_id = lobby_id
	is_lobby_host = false
	
	lobby_joined.emit(lobby_id)
	print("Joined private lobby: ", lobby_id)

## GENERAL LOBBY FUNCTIONS

func leave_lobby():
	"""Leave the current lobby"""
	if not current_lobby_id or not nakama_socket:
		return
	
	print("Leaving lobby: ", current_lobby_id)
	
	var result = await nakama_socket.leave_match_async(current_lobby_id)
	
	if not result.is_exception():
		print("Left lobby successfully")
		
		# Clean up lobby storage if host
		if is_lobby_host:
			await cleanup_lobby_storage()
	else:
		print("Error leaving lobby: ", result.get_exception())
	
	current_lobby_id = ""
	is_lobby_host = false

func cleanup_lobby_storage():
	"""Clean up lobby storage when host leaves"""
	if not nakama_session or current_lobby_id.is_empty():
		return
	
	print("Cleaning up lobby storage for: ", current_lobby_id)
	
	# Create storage objects to delete
	var public_delete = NakamaWriteStorageObject.new("public_lobbies", current_lobby_id, 1, 2, "", "")
	var private_delete = NakamaWriteStorageObject.new("private_lobbies", current_lobby_id, 1, 1, "", "")
	
	# Try deleting from public collection
	var public_result = await nakama_client.delete_storage_objects_async(nakama_session, [public_delete])
	if public_result.is_exception():
		print("Public lobby cleanup failed (expected if private): ", public_result.get_exception())
	
	# Try deleting from private collection  
	var private_result = await nakama_client.delete_storage_objects_async(nakama_session, [private_delete])
	if private_result.is_exception():
		print("Private lobby cleanup failed (expected if public): ", private_result.get_exception())

func get_lobby_info():
	"""Get current lobby information"""
	if not current_lobby_id or not nakama_session:
		return null
	
	print("Getting lobby info for: ", current_lobby_id)
	
	# Try to get from public lobbies first
	var storage_ids = []
	var storage_id = NakamaStorageObjectId.new("public_lobbies", current_lobby_id)
	storage_ids.append(storage_id)
	
	var result = await nakama_client.read_storage_objects_async(nakama_session, storage_ids)
	
	# If not found in public, try private
	if result.is_exception() or result.objects.size() == 0:
		storage_ids.clear()
		storage_id = NakamaStorageObjectId.new("private_lobbies", current_lobby_id)
		storage_ids.append(storage_id)
		result = await nakama_client.read_storage_objects_async(nakama_session, storage_ids)
	
	if result.is_exception() or result.objects.size() == 0:
		print("Lobby info not found in storage")
		return null
	
	var lobby_data_result = JSON.parse_string(result.objects[0].value)
	if lobby_data_result == null:
		print("Failed to parse lobby data")
		return null
	
	var lobby_data = lobby_data_result
	
	return {
		"id": current_lobby_id,
		"name": lobby_data.get("lobby_name", "Unknown"),
		"type": lobby_data.get("lobby_type", "unknown"),
		"players": lobby_data.get("current_players", 0),
		"max_players": lobby_data.get("max_players", 10),
		"host": lobby_data.get("host_name", "Unknown"),
		"is_host": is_lobby_host
	}

func send_game_data(data: Dictionary):
	"""Send game data to all players in lobby"""
	if not current_lobby_id or not nakama_socket:
		print("Cannot send game data: not in lobby or socket not connected")
		return
	
	# Send data through Nakama match
	var json_data = JSON.stringify(data)
	var result = await nakama_socket.send_match_data_async(current_lobby_id, 1, json_data.to_utf8_buffer())
	
	if result.is_exception():
		print("Failed to send match data: ", result.get_exception())
	else:
		print("Game data sent successfully")

func _exit_tree():
	"""Clean up when script is destroyed"""
	if current_lobby_id and is_lobby_host:
		await cleanup_lobby_storage()
	
	if nakama_socket and nakama_socket.is_connected_to_host():
		await leave_lobby()
		nakama_socket.close()
