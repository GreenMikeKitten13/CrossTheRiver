@tool
extends EditorPlugin

func _enter_tree():
	add_autoload_singleton("Nakama", "res://addons/nakama/nakama.gd")

func _exit_tree():
	remove_autoload_singleton("Nakama")