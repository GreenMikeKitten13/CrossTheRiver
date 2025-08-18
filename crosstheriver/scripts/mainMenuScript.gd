extends Control


#func _on_play_pressed() -> void:
#	changeScene.changeScene(changeScene.raceScene)


#func _on_forest_pressed() -> void:
#	changeScene.changeScene(changeScene.forestScene)


#func _on_credits_pressed() -> void:
#	pass # Replace with function body.

# mainMenuScript.gd - Modified to work with your existing UI

# UI References from your scene
# mainMenuScript.gd - Modified to work with your existing UI

# mainMenuScript.gd - Modified to work with your existing UI

# UI References from your scene
# mainMenuScript.gd - Modified to work with your existing UI

# UI References from your scene
@onready var main_background = %MainBackGround
@onready var lobby_background = %LobbyBackGround
@onready var lobby_manager = $LobbyManager

# Main menu buttons
@onready var play_button = $MainBackGround/VBoxContainer/Play
@onready var forest_button = $MainBackGround/VBoxContainer/Forest
@onready var credits_button = $MainBackGround/VBoxContainer/Credits

# Lobby UI elements
@onready var lobby_list_container = $MainBackGround/LobbyBackGround/ScrollContainer/VBoxContainer
@onready var create_private_button = $MainBackGround/LobbyBackGround/CreatePrivateLobby
@onready var create_public_button = $MainBackGround/LobbyBackGround/CreatePublicLobby
@onready var close_button = $MainBackGround/LobbyBackGround/Close
@onready var refresh_button = $MainBackGround/LobbyBackGround/refresh

# Store the original lobby buttons to clear them later
var original_lobby_buttons = []

# Dialog nodes (we'll create these dynamically)
var create_lobby_dialog: AcceptDialog
var join_private_dialog: AcceptDialog
var current_lobby_dialog: AcceptDialog

func _ready():
	# Connect lobby manager signals
	lobby_manager.lobby_created.connect(_on_lobby_created)
	lobby_manager.lobby_joined.connect(_on_lobby_joined)
	lobby_manager.lobby_error.connect(_on_lobby_error)
	
	# Connect existing buttons
	create_private_button.pressed.connect(_on_create_private_lobby_pressed)
	create_public_button.pressed.connect(_on_create_public_lobby_pressed)
	close_button.pressed.connect(_on_close_lobby_browser)
	refresh_button.pressed.connect(_on_refresh_lobbies_pressed)
	
	# Store original lobby buttons
	for child in lobby_list_container.get_children():
		if child is Button:
			original_lobby_buttons.append(child)
			child.queue_free()  # Remove placeholder buttons
	
	# Initially hide lobby browser
	lobby_background.hide()
	
	# Create dialogs
	create_dialogs()

func create_dialogs():
	# Create lobby dialog
	create_lobby_dialog = AcceptDialog.new()
	create_lobby_dialog.title = "Create Lobby"
	create_lobby_dialog.size = Vector2(400, 350)
	
	var create_vbox = VBoxContainer.new()
	create_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	create_vbox.add_theme_constant_override("separation", 10)
	
	# Lobby name
	var name_label = Label.new()
	name_label.text = "Lobby Name:"
	create_vbox.add_child(name_label)
	
	var name_input = LineEdit.new()
	name_input.name = "lobby_name_input"
	name_input.placeholder_text = "Enter lobby name"
	create_vbox.add_child(name_input)
	
	# Max players
	var max_label = Label.new()
	max_label.text = "Max Players (2-10):"
	create_vbox.add_child(max_label)
	
	var max_input = SpinBox.new()
	max_input.name = "max_players_input"
	max_input.min_value = 2
	max_input.max_value = 10
	max_input.value = 8
	create_vbox.add_child(max_input)
	
	# Password (for private lobbies)
	var password_label = Label.new()
	password_label.name = "password_label"
	password_label.text = "Password:"
	create_vbox.add_child(password_label)
	
	var password_input = LineEdit.new()
	password_input.name = "password_input"
	password_input.placeholder_text = "Enter password"
	password_input.secret = true
	create_vbox.add_child(password_input)
	
	create_lobby_dialog.add_child(create_vbox)
	add_child(create_lobby_dialog)
	
	# Join private lobby dialog
	join_private_dialog = AcceptDialog.new()
	join_private_dialog.title = "Join Private Lobby"
	join_private_dialog.size = Vector2(400, 200)
	
	var join_vbox = VBoxContainer.new()
	join_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	join_vbox.add_theme_constant_override("separation", 10)
	
	var id_label = Label.new()
	id_label.text = "Lobby ID:"
	join_vbox.add_child(id_label)
	
	var id_input = LineEdit.new()
	id_input.name = "lobby_id_input"
	id_input.placeholder_text = "Enter lobby ID"
	join_vbox.add_child(id_input)
	
	var join_pass_label = Label.new()
	join_pass_label.text = "Password:"
	join_vbox.add_child(join_pass_label)
	
	var join_pass_input = LineEdit.new()
	join_pass_input.name = "join_password_input"
	join_pass_input.placeholder_text = "Enter password"
	join_pass_input.secret = true
	join_vbox.add_child(join_pass_input)
	
	join_private_dialog.add_child(join_vbox)
	add_child(join_private_dialog)
	
	# Current lobby dialog
	current_lobby_dialog = AcceptDialog.new()
	current_lobby_dialog.title = "Current Lobby"
	current_lobby_dialog.size = Vector2(500, 400)
	
	var current_vbox = VBoxContainer.new()
	current_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	current_vbox.add_theme_constant_override("separation", 10)
	
	var lobby_info = RichTextLabel.new()
	lobby_info.name = "lobby_info"
	lobby_info.custom_minimum_size = Vector2(400, 200)
	current_vbox.add_child(lobby_info)
	
	var button_hbox = HBoxContainer.new()
	current_vbox.add_child(button_hbox)
	
	var start_game_btn = Button.new()
	start_game_btn.name = "start_game_button"
	start_game_btn.text = "Start Game"
	start_game_btn.pressed.connect(_on_start_game_pressed)
	button_hbox.add_child(start_game_btn)
	
	var leave_btn = Button.new()
	leave_btn.text = "Leave Lobby"
	leave_btn.pressed.connect(_on_leave_lobby_pressed)
	button_hbox.add_child(leave_btn)
	
	current_lobby_dialog.add_child(current_vbox)
	add_child(current_lobby_dialog)

# Your existing button handlers
func _on_play_pressed():
	lobby_background.show()
	refresh_public_lobbies()

func _on_forest_pressed():
	# Your existing forest logic
	pass

func _on_credits_pressed():
	# Your existing credits logic
	pass

# New lobby handlers
func _on_create_private_lobby_pressed():
	# Show password field for private lobby
	var password_label = create_lobby_dialog.find_child("password_label", true)
	var password_input = create_lobby_dialog.find_child("password_input", true)
	if password_label and password_input:
		password_label.show()
		password_input.show()
	
	create_lobby_dialog.popup_centered()
	if not create_lobby_dialog.confirmed.is_connected(_on_create_private_confirmed):
		create_lobby_dialog.confirmed.connect(_on_create_private_confirmed, CONNECT_ONE_SHOT)

func _on_create_public_lobby_pressed():
	# Hide password field for public lobby
	var password_label = create_lobby_dialog.find_child("password_label", true)
	var password_input = create_lobby_dialog.find_child("password_input", true)
	if password_label and password_input:
		password_label.hide()
		password_input.hide()
	
	create_lobby_dialog.popup_centered()
	if not create_lobby_dialog.confirmed.is_connected(_on_create_public_confirmed):
		create_lobby_dialog.confirmed.connect(_on_create_public_confirmed, CONNECT_ONE_SHOT)

func _on_close_lobby_browser():
	lobby_background.hide()

func _on_refresh_lobbies_pressed():
	refresh_public_lobbies()

# Create lobby confirmations
func _on_create_private_confirmed():
	print("=== DEBUG: Private lobby confirmation ===")
	
	# Try multiple ways to find the elements
	var name_input = create_lobby_dialog.find_child("lobby_name_input", true)
	var max_input = create_lobby_dialog.find_child("max_players_input", true)
	var password_input = create_lobby_dialog.find_child("password_input", true)
	
	print("Name input found: ", name_input != null)
	print("Max input found: ", max_input != null)
	print("Password input found: ", password_input != null)
	
	# If find_child doesn't work, try getting the VBox and searching there
	if not name_input or not max_input or not password_input:
		print("Trying VBox approach...")
		var vbox = create_lobby_dialog.get_child(0)  # Should be the VBoxContainer
		if vbox:
			print("VBox found, children count: ", vbox.get_child_count())
			for i in range(vbox.get_child_count()):
				var child = vbox.get_child(i)
				print("Child ", i, ": ", child.name, " (", child.get_class(), ")")
				
				if child.name == "lobby_name_input":
					name_input = child
				elif child.name == "max_players_input":
					max_input = child
				elif child.name == "password_input":
					password_input = child
	
	if not name_input or not max_input or not password_input:
		show_error("Dialog elements not found - check console for debug info")
		return
	
	var lobby_name = name_input.text.strip_edges()
	var max_players = int(max_input.value)
	var password = password_input.text.strip_edges()
	
	print("Values - Name: '", lobby_name, "', Max: ", max_players, ", Password: '", password, "'")
	
	if lobby_name.is_empty():
		show_error("Please enter a lobby name")
		return
	
	if password.is_empty():
		show_error("Please enter a password")
		return
	
	print("Creating private lobby...")
	lobby_manager.create_private_lobby(lobby_name, password, max_players)

func _on_create_public_confirmed():
	print("=== DEBUG: Public lobby confirmation ===")
	
	var name_input = create_lobby_dialog.find_child("lobby_name_input", true)
	var max_input = create_lobby_dialog.find_child("max_players_input", true)
	
	print("Name input found: ", name_input != null)
	print("Max input found: ", max_input != null)
	
	# Try VBox approach if needed
	if not name_input or not max_input:
		print("Trying VBox approach...")
		var vbox = create_lobby_dialog.get_child(0)
		if vbox:
			for i in range(vbox.get_child_count()):
				var child = vbox.get_child(i)
				if child.name == "lobby_name_input":
					name_input = child
				elif child.name == "max_players_input":
					max_input = child
	
	if not name_input or not max_input:
		show_error("Dialog elements not found - check console for debug info")
		return
	
	var lobby_name = name_input.text.strip_edges()
	var max_players = int(max_input.value)
	
	print("Values - Name: '", lobby_name, "', Max: ", max_players)
	
	if lobby_name.is_empty():
		show_error("Please enter a lobby name")
		return
	
	print("Creating public lobby...")
	lobby_manager.create_public_lobby(lobby_name, max_players)

# Refresh public lobbies
func refresh_public_lobbies():
	# Clear existing lobby buttons (keep the create/refresh buttons)
	for child in lobby_list_container.get_children():
		if child is Button:
			child.queue_free()
	
	# Get lobbies from manager
	var lobbies = await lobby_manager.list_public_lobbies()
	
	# Add lobby buttons
	for lobby in lobbies:
		var lobby_button = Button.new()
		lobby_button.text = "%s (%d/%d) - %s" % [
			lobby["name"],
			lobby["players"],
			lobby["max_players"],
			lobby["host"]
		]
		
		# Connect button to join function
		lobby_button.pressed.connect(_on_public_lobby_selected.bind(lobby["id"]))
		lobby_list_container.add_child(lobby_button)
	
	if lobbies.is_empty():
		var no_lobbies = Label.new()
		no_lobbies.text = "No public lobbies available"
		no_lobbies.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lobby_list_container.add_child(no_lobbies)

func _on_public_lobby_selected(lobby_id: String):
	lobby_manager.join_public_lobby(lobby_id)

# Lobby manager event handlers
func _on_lobby_created(lobby_id: String):
	print("Lobby created: ", lobby_id)
	show_current_lobby()

func _on_lobby_joined(lobby_id: String):
	print("Joined lobby: ", lobby_id)
	show_current_lobby()

func _on_lobby_error(message: String):
	show_error(message)

func show_current_lobby():
	lobby_background.hide()
	
	# Update lobby info
	var lobby_info = await lobby_manager.get_lobby_info()
	if lobby_info:
		var info_label = current_lobby_dialog.find_child("lobby_info", true)
		if info_label:
			var info_text = "Lobby: %s\nType: %s\nPlayers: %d/%d\nHost: %s\nLobby ID: %s" % [
				lobby_info["name"],
				lobby_info["type"],
				lobby_info["players"],
				lobby_info["max_players"],
				lobby_info["host"],
				lobby_info["id"]
			]
			info_label.text = info_text
		
		# Show start game button only if host
		var start_button = current_lobby_dialog.find_child("start_game_button", true)
		if start_button:
			start_button.visible = lobby_info["is_host"]
	
	current_lobby_dialog.popup_centered()

func _on_start_game_pressed():
	# TODO: Implement game start logic
	print("Starting game...")
	# Change to game scene
	# get_tree().change_scene_to_file("res://game_scene.tscn")

func _on_leave_lobby_pressed():
	lobby_manager.leave_lobby()
	current_lobby_dialog.hide()
	lobby_background.show()

func show_error(message: String):
	# Create a simple one-time error popup
	var error_popup = AcceptDialog.new()
	error_popup.dialog_text = message
	error_popup.title = "Error"
	
	# Add to scene tree temporarily
	get_tree().root.add_child(error_popup)
	
	# Show and auto-remove when closed
	error_popup.popup_centered()
	error_popup.confirmed.connect(func():
		error_popup.queue_free()
	)
	error_popup.canceled.connect(func():
		error_popup.queue_free()
	)
	
	
