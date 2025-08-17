extends Control


func _on_play_pressed() -> void:
	changeScene.changeScene(changeScene.raceScene)


func _on_forest_pressed() -> void:
	changeScene.changeScene(changeScene.forestScene)


func _on_credits_pressed() -> void:
	pass # Replace with function body.
