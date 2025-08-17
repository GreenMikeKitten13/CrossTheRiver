extends CanvasLayer


const raceScene = ("res://scenes/RaceScene.tscn")
const forestScene = ("res://scenes/forestScene.tscn")

const MainMenuScene = ("res://scenes/Main Menu.tscn")
var changed:bool = false
@onready var animationPlayer:AnimationPlayer = self.get_child(-1)

func changeScene(scenePath) -> void:
	animationPlayer.play("Fade")
	await animationPlayer.animation_finished
	
	get_tree().change_scene_to_file(scenePath)
	changed = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.MOUSE_MODE_CAPTURED and changed:
		animationPlayer.play_backwards("Fade")
		changed = false
