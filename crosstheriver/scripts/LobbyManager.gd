# LobbyManager.gd
extends Node

signal lobby_created(lobby_id)
signal lobby_joined(lobby_id)
signal lobby_error(message)
#signal player_joined_lobby(player_name)
#signal player_left_lobby(player_name)

var nakama_client: NakamaClient
var nakama_session: NakamaSession
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
		lobby_error.emit("Failed to connect: " + session_result.get_exception().message)
		return
	
	nakama_session = session_result#.session
	print("Connected! User ID: ", nakama_session.user_id)

## PUBLIC LOBBY FUNCTIONS

func create_public_lobby(lobby_name: String, max_players: int = 10):
	"""Create a public lobby that anyone can join"""
	if not nakama_session:
		lobby_error.emit("Not connected to server")
		return
	
	print("Creating public lobby: ", lobby_name)
	
	# Match metadata for public lobby
	var match_metadata = {
		"lobby_name": lobby_name,
		"lobby_type": "public",
		"max_players": max_players,
		"current_players": 1,
		"host_name": nakama_session.username
	}
	
	var result = await nakama_client.create_match_async(nakama_session)
	
	if result.is_exception():
		lobby_error.emit("Failed to create lobby: " + result.get_exception().message)
		return
	
	current_lobby_id = result.match_id
	is_lobby_host = true
	
	# Set match metadata
	await nakama_client.update_match_async(nakama_session, current_lobby_id, match_metadata)
	
	lobby_created.emit(current_lobby_id)
	print("Public lobby created with ID: ", current_lobby_id)

func join_public_lobby(lobby_id: String):
	"""Join a public lobby by ID"""
	if not nakama_session:
		lobby_error.emit("Not connected to server")
		return
	
	print("Joining public lobby: ", lobby_id)
	
	var result = await nakama_client.join_match_async(nakama_session, lobby_id)
	
	if result.is_exception():
		lobby_error.emit("Failed to join lobby: " + result.get_exception().message)
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
	
	var result = await nakama_client.list_matches_async(nakama_session, 0, 20, 10, true, "", "")
	
	if result.is_exception():
		lobby_error.emit("Failed to get lobby list: " + result.get_exception().message)
		return []
	
	var public_lobbies = []
	for match in result.matches:
		# Filter for public lobbies only
		if match.metadata.has("lobby_type") and match.metadata["lobby_type"] == "public":
			public_lobbies.append({
				"id": match.match_id,
				"name": match.metadata.get("lobby_name", "Unknown"),
				"players": match.metadata.get("current_players", 0),
				"max_players": match.metadata.get("max_players", 10),
				"host": match.metadata.get("host_name", "Unknown")
			})
	
	return public_lobbies

## PRIVATE LOBBY FUNCTIONS

func create_private_lobby(lobby_name: String, password: String, max_players: int = 10):
	"""Create a private lobby with password protection"""
	if not nakama_session:
		lobby_error.emit("Not connected to server")
		return
	
	print("Creating private lobby: ", lobby_name)
	
	# Hash the password for basic security
	var password_hash = password.sha256_text()
	
	# Match metadata for private lobby
	var match_metadata = {
		"lobby_name": lobby_name,
		"lobby_type": "private",
		"password_hash": password_hash,
		"max_players": max_players,
		"current_players": 1,
		"host_name": nakama_session.username
	}
	
	var result = await nakama_client.create_match_async(nakama_session)
	
	if result.is_exception():
		lobby_error.emit("Failed to create private lobby: " + result.get_exception().message)
		return
	
	current_lobby_id = result.match_id
	is_lobby_host = true
	
	# Set match metadata
	await nakama_client.update_match_async(nakama_session, current_lobby_id, match_metadata)
	
	lobby_created.emit(current_lobby_id)
	print("Private lobby created with ID: ", current_lobby_id)

func join_private_lobby(lobby_id: String, password: String):
	"""Join a private lobby with password"""
	if not nakama_session:
		lobby_error.emit("Not connected to server")
		return
	
	print("Attempting to join private lobby: ", lobby_id)
	
	# First, get the match info to check password
	var match_info = await nakama_client.get_match_async(nakama_session, lobby_id)
	
	if match_info.is_exception():
		lobby_error.emit("Lobby not found")
		return
	
	# Check password
	var stored_hash = match_info.match.metadata.get("password_hash", "")
	var provided_hash = password.sha256_text()
	
	if stored_hash != provided_hash:
		lobby_error.emit("Incorrect password")
		return
	
	# Password correct, join the match
	var result = await nakama_client.join_match_async(nakama_session, lobby_id)
	
	if result.is_exception():
		lobby_error.emit("Failed to join lobby: " + result.get_exception().message)
		return
	
	current_lobby_id = lobby_id
	is_lobby_host = false
	
	lobby_joined.emit(lobby_id)
	print("Joined private lobby: ", lobby_id)

## GENERAL LOBBY FUNCTIONS

func leave_lobby():
	"""Leave the current lobby"""
	if not current_lobby_id:
		return
	
	print("Leaving lobby: ", current_lobby_id)
	
	var result = await nakama_client.leave_match_async(nakama_session, current_lobby_id)
	
	if not result.is_exception():
		print("Left lobby successfully")
	
	current_lobby_id = ""
	is_lobby_host = false

func get_lobby_info():
	"""Get current lobby information"""
	if not current_lobby_id:
		return null
	
	var result = await nakama_client.get_match_async(nakama_session, current_lobby_id)
	
	if result.is_exception():
		return null
	
	return {
		"id": current_lobby_id,
		"name": result.match.metadata.get("lobby_name", "Unknown"),
		"type": result.match.metadata.get("lobby_type", "unknown"),
		"players": result.match.metadata.get("current_players", 0),
		"max_players": result.match.metadata.get("max_players", 10),
		"host": result.match.metadata.get("host_name", "Unknown"),
		"is_host": is_lobby_host
	}

func send_game_data(data: Dictionary):
	"""Send game data to all players in lobby"""
	if not current_lobby_id:
		return
	
	# Send data through Nakama match
	var json_data = JSON.stringify(data)
	await nakama_client.send_match_data_async(nakama_session, current_lobby_id, 1, json_data)
